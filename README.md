# cloud-native-platform

> A production-grade Internal Developer Platform demonstrating the complete 2026 DevOps stack:
> **GitHub Actions CI → ArgoCD GitOps CD → Kubernetes → Argo Rollouts (canary) → Kyverno (policy-as-code) → Prometheus + Grafana + Loki**.
> Runs 100% locally with kind. Zero cloud cost.

[![CI Pipeline](https://github.com/chandanvura/cloud-native-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/chandanvura/cloud-native-platform/actions/workflows/ci.yml)

---

## What makes this different

| Capability | This project | Typical DevOps portfolio |
|---|---|---|
| CD approach | GitOps — ArgoCD syncs cluster to Git | `helm upgrade` inside the pipeline |
| Deployment strategy | Argo Rollouts canary with Prometheus analysis | Rolling update only |
| Policy enforcement | Kyverno blocks non-compliant pods at admission | None |
| Log aggregation | Loki — searchable from Grafana | stdout only |
| Security | Trivy CVE scan in CI, non-root containers, readOnlyRootFilesystem | Trivy only |
| Local setup | Full 3-service K8s platform on kind, 1 script | Docker Compose |
| Inter-service comms | order-service calls user-service via K8s DNS | Single service |

---

## Architecture

```
 Developer
     │
     ▼  git push to main
 ┌──────────────────────────────────────────────────────────┐
 │  GitHub Actions CI  (cloud-native-platform repo)         │
 │                                                          │
 │  detect-changes → build → test → trivy-scan              │
 │  → docker-build → push to GHCR                          │
 │  → update image tag in platform-config repo             │
 └──────────────────────────┬───────────────────────────────┘
                            │  commits new image tag
                            ▼
 ┌──────────────────────────────────────────────────────────┐
 │  platform-config repo  (GitOps config)                   │
 │                                                          │
 │  apps/                  ← ArgoCD App of Apps             │
 │  helm/user-service/     ← Helm chart (Rollout + Service) │
 │  environments/nonprod/  ← values.yaml (image.tag here)  │
 └──────────────────────────┬───────────────────────────────┘
                            │  ArgoCD detects commit
                            ▼
 ┌──────────────────────────────────────────────────────────┐
 │  Kubernetes Cluster  (kind locally / EKS on AWS)         │
 │                                                          │
 │  namespace: apps                                         │
 │  ├─ user-service      (Argo Rollout — canary)            │
 │  ├─ order-service     (Argo Rollout — canary)            │
 │  └─ notification-svc  (Argo Rollout — canary)            │
 │                                                          │
 │  namespace: platform-system                              │
 │  ├─ ArgoCD            (GitOps operator)                  │
 │  ├─ Kyverno           (Policy-as-Code enforcement)       │
 │  └─ Argo Rollouts     (Canary deployment controller)     │
 │                                                          │
 │  namespace: monitoring                                   │
 │  ├─ Prometheus        (metrics scraping)                 │
 │  ├─ Grafana           (dashboards + alerts)              │
 │  └─ Loki + Promtail   (log aggregation)                  │
 └──────────────────────────────────────────────────────────┘
```

### Canary deployment flow (Argo Rollouts)

```
New image tag pushed
        │
        ▼
  20% traffic → canary pods
        │
        ▼  (30 seconds)
  Prometheus AnalysisTemplate checks:
  success_rate = non-5xx / total > 95%?
        │
    ┌───┴───┐
    │       │
   YES      NO
    │       │
    ▼       ▼
  50%    ABORT → stable version
  then        restored instantly
  100%
```

---

## Services

| Service | Port | Calls |
|---|---|---|
| user-service | 8081 | — |
| order-service | 8082 | user-service, notification-service |
| notification-service | 8083 | — |

Inter-service communication uses Kubernetes internal DNS:
`http://user-service.apps.svc.cluster.local:8081`

---

## Tech stack

| Layer | Technology |
|---|---|
| Language | Java 17, Spring Boot 3 |
| Container | Docker (multi-stage, non-root, readOnlyRootFilesystem) |
| Registry | GitHub Container Registry (GHCR) |
| CI | GitHub Actions (path-based triggers, Trivy, Buildx) |
| CD | ArgoCD (App of Apps, GitOps, selfHeal) |
| Orchestration | Kubernetes (kind locally, EKS on AWS) |
| Packaging | Helm 3 (per-service charts, env value overrides) |
| Deployments | Argo Rollouts (canary with Prometheus analysis) |
| Policy | Kyverno (4 ClusterPolicies — labels, limits, no-root, no-latest) |
| Metrics | Prometheus + Grafana (kube-prometheus-stack) |
| Logs | Loki + Promtail + Grafana |
| IaC | Terraform (EKS + VPC + ECR — optional cloud deploy) |

---

## Quick start — run locally (free, no cloud needed)

### Prerequisites
Docker Desktop, kind, kubectl, helm — see [docs/prerequisites.md](docs/prerequisites.md)

```bash
# Clone
git clone https://github.com/chandanvura/cloud-native-platform.git
cd cloud-native-platform

# Bootstrap everything in one command (~8 minutes first time)
chmod +x scripts/setup-local.sh
./scripts/setup-local.sh
```

### Access points after setup

| Service | URL | Credentials |
|---|---|---|
| ArgoCD UI | https://localhost:8090 | admin / (printed by script) |
| Grafana | http://localhost:3000 | admin / admin123 |
| Prometheus | http://localhost:9090 | — |
| Alertmanager | http://localhost:9093 | — |

### Deploy the applications via GitOps

```bash
# Register your platform-config repo with ArgoCD
argocd login localhost:8090 --username admin --insecure \
  --password $(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

argocd repo add https://github.com/chandanvura/platform-config \
  --username chandanvura --password <your-github-pat>

# Bootstrap all services via App of Apps
kubectl apply -f https://raw.githubusercontent.com/chandanvura/platform-config/main/apps/app-of-apps.yaml

# Watch ArgoCD sync everything
argocd app list --watch
```

### Test locally with Docker Compose (no Kubernetes needed)

```bash
# Start all 3 services + Prometheus + Grafana
docker-compose up -d --build

# Test
curl http://localhost:8081/api/users
curl http://localhost:8081/api/users/u001
curl -X POST http://localhost:8082/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u001","item":"PlayStation 5","quantity":"1"}'
curl http://localhost:8083/api/notifications

# Stop
docker-compose down
```

---

## GitOps flow — how a code change flows to the cluster

```bash
# 1. Developer changes user-service code and pushes to main
git commit -am "feat: add user search endpoint"
git push origin main

# 2. GitHub Actions detects change in services/user-service/ (path filter)
#    Runs: build → test → trivy → docker build → push to GHCR
#    Then: updates environments/nonprod/values/user-service-values.yaml
#    with the new image tag (e.g. abc1234)

# 3. ArgoCD detects the commit in platform-config repo (polls every 3 min)
#    Shows user-service as OutOfSync
#    Automatically syncs (selfHeal: true)

# 4. Argo Rollouts starts canary:
#    20% traffic to new pods → wait 30s → 50% → wait 30s → 100%

# 5. Prometheus AnalysisTemplate validates success rate during canary
#    If < 95% success rate → automatic abort → stable version restored

# Watch it:
kubectl argo rollouts get rollout user-service -n apps --watch
```

---

## Kyverno policy enforcement

Try deploying a non-compliant pod — it gets blocked at admission:

```bash
# Blocked: no resource limits
kubectl run bad-pod --image=nginx -n apps
# Error: CPU and memory limits are required on all pods

# Blocked: running as root
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: root-pod
  namespace: apps
spec:
  containers:
  - name: c
    image: nginx
    securityContext:
      runAsNonRoot: false
    resources:
      limits: {memory: 128Mi, cpu: 100m}
EOF
# Error: Containers must not run as root
```

---

## Repository structure

```
cloud-native-platform/       ← THIS repo (application code + CI)
├── services/
│   ├── user-service/        Java 17 Spring Boot REST API
│   ├── order-service/       Calls user-service + notification-service
│   └── notification-service/Receives events from order-service
├── .github/workflows/
│   └── ci.yml               Path-based CI: build, test, scan, push, update gitops
├── platform/
│   ├── kyverno/             4 ClusterPolicy files
│   └── monitoring/          Prometheus config + alert rules + Grafana provisioning
├── kind-config/             kind cluster definition
├── docker-compose.yml       Local dev without Kubernetes
├── scripts/
│   ├── setup-local.sh       One-command platform bootstrap
│   ├── teardown.sh          Tear down kind cluster
│   └── test-services.sh     End-to-end API tests
└── docs/
    ├── prerequisites.md     Install guide
    └── runbook.md           Incident response procedures

platform-config/             ← SECOND repo (GitOps config — ArgoCD watches this)
├── apps/                    ArgoCD Application manifests (App of Apps)
├── helm/                    Helm charts (Rollout + Service + AnalysisTemplate)
└── environments/
    ├── nonprod/values/      CI updates image.tag here automatically
    └── prod/values/         Manually promoted via PR
```

---

## Required GitHub setup

### Repository secrets (cloud-native-platform repo)

| Secret | Value |
|---|---|
| `GITOPS_TOKEN` | GitHub PAT with `repo` write access to `platform-config` |

### Repository settings

Settings → Actions → General → Workflow permissions → **Read and write permissions**

---

## What I learned building this

This project implements the architecture pattern used by Adobe, Goldman Sachs, and Spotify — GitOps with ArgoCD, canary deployments with automated analysis, and policy-as-code with Kyverno. The two-repo pattern (application code separate from GitOps config) provides a clean audit trail: every production deployment is a reviewed Git commit in `platform-config`.

The canary + Prometheus analysis pattern eliminates manual rollback decisions. If a bad deployment degrades the success rate below 95%, Argo Rollouts aborts automatically — no on-call engineer needed at 3am.

---

## Next steps

- [ ] Add Istio service mesh for mTLS between services
- [ ] Add Backstage IDP for developer self-service
- [ ] Add OpenTelemetry distributed tracing
- [ ] Add `tfsec` / Checkov for Terraform security scanning

---

## Author

**Chandan Vura** — DevOps Engineer with production experience at Sony Interactive Entertainment (Java microservice deployments, Jenkins CI/CD, Kubernetes operations, Prometheus/Grafana monitoring).

GitHub: [chandanvura](https://github.com/chandanvura)
