#!/bin/bash
# scripts/teardown.sh — removes the kind cluster and all resources
set -euo pipefail

echo "Stopping port-forwards..."
pkill -f "kubectl port-forward" 2>/dev/null || true

echo "Deleting kind cluster 'platform'..."
kind delete cluster --name platform

echo "Done. All resources removed."
