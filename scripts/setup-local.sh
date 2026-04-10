#!/bin/bash
# scripts/setup-local.sh
# ─────────────────────────────────────────────────────────────────
# Bootstraps the full cloud-native-platform locally using kind.
# Prerequisites: docker, kind, kubectl, helm, argocd CLI
#
# Usage:
#   chmod +x scripts/setup-local.sh
#   ./scripts/setup-local.sh
#
# What it does:
#   1. Creates a 3-node kind cluster
#   2. Installs ArgoCD
#   3. Installs kube-prometheus-stack (Prometheus + Grafana)
#   4. Installs Loki (log aggregation)
#   5. Installs Kyverno + all policies
#   6. Installs Argo Rollouts
#   7. Creates namespaces
#   8. Starts port-forwards in the background
#   9. Prints all access URLs and credentials
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; AMBER='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${GREEN}[OK]${NC}    $1"; }
waiting() { echo -e "${AMBER}[WAIT]${NC}  $1"; }
section() { echo -e "\n${BOLD}── $1${NC}"; }
err()     { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}  cloud-native-platform — local bootstrap${NC}"
echo -e "  GitOps • ArgoCD • Kyverno • Argo Rollouts • Prometheus • Grafana • Loki"
echo ""

# ── Check prerequisites ──────────────────────────────────────────
section "Checking prerequisites"
for cmd in docker kind kubectl helm; do
  command -v "$cmd" >/dev/null 2>&1 \
    && info "$cmd found ($(${cmd} version --short 2>/dev/null | head -1 || echo 'ok'))" \
    || err "$cmd not found. See docs/prerequisites.md"
done
# ArgoCD CLI is optional — we fall back to kubectl
command -v argocd >/dev/null 2>&1 && info "argocd CLI found" || info "argocd CLI not found — using kubectl only (optional)"

# ── Create kind cluster ──────────────────────────────────────────
section "Creating kind cluster 'platform'"
if kind get clusters 2>/dev/null | grep -q "^platform$"; then
  info "Cluster 'platform' already exists — skipping creation"
else
  waiting "Creating 3-node kind cluster (takes ~2 min)..."
  kind create cluster --config kind-config/kind-config.yaml
  info "Cluster created"
fi
kubectl config use-context kind-platform
info "kubectl context set to kind-platform"

# ── Namespaces ───────────────────────────────────────────────────
section "Creating namespaces"
for ns in argocd monitoring kyverno argo-rollouts apps; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - -q
  info "namespace/$ns ready"
done

# ── ArgoCD ───────────────────────────────────────────────────────
section "Installing ArgoCD"
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --wait=false -q
waiting "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd
info "ArgoCD ready"

# ── Helm repos ───────────────────────────────────────────────────
section "Adding Helm repositories"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts -q 2>/dev/null || true
helm repo add grafana               https://grafana.github.io/helm-charts -q              2>/dev/null || true
helm repo add kyverno               https://kyverno.github.io/kyverno/ -q                2>/dev/null || true
helm repo update -q
info "Helm repos updated"

# ── kube-prometheus-stack ────────────────────────────────────────
section "Installing Prometheus + Grafana (kube-prometheus-stack)"
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123 \
  --set grafana.service.type=ClusterIP \
  --set prometheus.prometheusSpec.retention=7d \
  --set alertmanager.enabled=true \
  --wait --timeout 10m -q
info "Prometheus + Grafana ready"

# ── Loki ─────────────────────────────────────────────────────────
section "Installing Loki (log aggregation)"
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true \
  --wait --timeout 5m -q
info "Loki ready"

# ── Kyverno ──────────────────────────────────────────────────────
section "Installing Kyverno + policies"
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --wait --timeout 5m -q
# Apply all policy files
kubectl apply -f platform/kyverno/ -q
info "Kyverno + 4 policies installed"

# ── Argo Rollouts ────────────────────────────────────────────────
section "Installing Argo Rollouts"
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml \
  --wait=false -q
waiting "Waiting for Argo Rollouts controller..."
kubectl wait --for=condition=available --timeout=120s \
  deployment/argo-rollouts -n argo-rollouts
info "Argo Rollouts ready"

# ── Port-forwards ────────────────────────────────────────────────
section "Starting port-forwards"
# Kill any existing port-forwards first
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

kubectl port-forward svc/argocd-server                       -n argocd     8090:443 &>/dev/null &
kubectl port-forward svc/kube-prometheus-stack-grafana        -n monitoring 3000:80  &>/dev/null &
kubectl port-forward svc/kube-prometheus-stack-prometheus     -n monitoring 9090:9090 &>/dev/null &
kubectl port-forward svc/kube-prometheus-stack-alertmanager   -n monitoring 9093:9093 &>/dev/null &
sleep 2
info "Port-forwards running in background"

# ── Get ArgoCD password ──────────────────────────────────────────
ARGO_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d")

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ────────────────────────────────────────────────${NC}"
echo -e "  ${GREEN}${BOLD}Platform is ready!${NC}"
echo -e "${BOLD}  ────────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${BOLD}ArgoCD${NC}       https://localhost:8090"
echo -e "               Username: ${AMBER}admin${NC}"
echo -e "               Password: ${AMBER}${ARGO_PASS}${NC}"
echo ""
echo -e "  ${BOLD}Grafana${NC}      http://localhost:3000"
echo -e "               Username: ${AMBER}admin${NC} / Password: ${AMBER}admin123${NC}"
echo ""
echo -e "  ${BOLD}Prometheus${NC}   http://localhost:9090"
echo -e "  ${BOLD}Alertmanager${NC} http://localhost:9093"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "  1. Push images to GHCR from cloud-native-platform repo"
echo -e "  2. Apply App of Apps:"
echo -e "     ${AMBER}kubectl apply -f platform-config/apps/app-of-apps.yaml${NC}"
echo -e "  3. Watch services deploy in ArgoCD UI"
echo -e "  4. Test services:"
echo -e "     ${AMBER}kubectl port-forward svc/user-service -n apps 8081:80 &${NC}"
echo -e "     ${AMBER}curl http://localhost:8081/api/users${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "  kubectl get pods -A                          # all pods"
echo -e "  kubectl argo rollouts list rollouts -n apps  # rollout status"
echo -e "  argocd app list                              # ArgoCD apps"
echo ""
