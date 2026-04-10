# Prerequisites

Everything needed to run this project locally. All tools are free.

## Required tools

### Docker Desktop
Download: https://docs.docker.com/get-docker/
Required for kind to create Kubernetes nodes as Docker containers.

### kind — Kubernetes in Docker
```bash
# Mac
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# Windows
choco install kind
```

### kubectl
```bash
# Mac
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl

# Windows
choco install kubernetes-cli
```

### Helm
```bash
# Mac
brew install helm

# Linux / Windows
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### ArgoCD CLI (optional — you can use the UI instead)
```bash
# Mac
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd && sudo mv argocd /usr/local/bin/argocd
```

### Argo Rollouts kubectl plugin (optional)
```bash
# Mac
brew install argoproj/tap/kubectl-argo-rollouts

# Linux
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

## Verify everything is installed

```bash
docker --version
kind version
kubectl version --client
helm version
argocd version --client 2>/dev/null || echo "argocd optional"
```

## Minimum system requirements

- Docker Desktop with at least **6GB RAM** allocated (Settings → Resources)
- 4 CPUs
- 20GB free disk space (for Docker images)
