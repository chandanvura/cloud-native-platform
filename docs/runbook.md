# Incident Runbook

Standard operating procedures for common incidents on cloud-native-platform.

## Runbook structure: Detect → Mitigate → Investigate → Fix → Prevent

---

## Incident 1: Service is returning 5xx errors

**Detect:** Prometheus alert `HighErrorRate` fires. Grafana shows error rate spike.

**Mitigate:** Identify if a recent deployment caused it.
```bash
# Check rollout history
kubectl argo rollouts history rollout/user-service -n apps

# If latest deployment is the cause — abort the canary immediately
kubectl argo rollouts abort user-service -n apps

# This rolls traffic back to the stable version instantly
```

**Investigate:**
```bash
kubectl logs -l app=user-service -n apps --tail=100 | grep -i error
kubectl describe rollout user-service -n apps
```

**Fix:** Fix the code, push, let the pipeline run again.

**Prevent:** Add a unit test or integration test covering the failed path.

---

## Incident 2: ArgoCD shows app as OutOfSync but not syncing

**Detect:** ArgoCD UI shows yellow OutOfSync badge. Manual sync fails.

**Investigate:**
```bash
argocd app get user-service
argocd app diff user-service   # shows exact diff
kubectl get events -n apps --sort-by='.lastTimestamp' | tail -20
```

**Common causes:**
- Kyverno policy violation blocking pod creation → read the event, fix the manifest
- Image pull error (wrong tag or no GHCR access) → check image exists: `docker pull ghcr.io/chandanvura/user-service:TAG`
- Resource quota exceeded → `kubectl describe resourcequota -n apps`

**Fix:**
```bash
argocd app sync user-service --force
```

---

## Incident 3: Pod stuck in CrashLoopBackOff

```bash
kubectl get pods -n apps
kubectl describe pod <pod-name> -n apps   # read Events section
kubectl logs <pod-name> -n apps --previous   # logs from crashed instance
```

**Common causes:**
- Missing environment variable → check values file in platform-config
- OOMKilled → increase memory limits in values file
- Java startup exception → read stack trace in logs

---

## Incident 4: Kyverno blocking a legitimate deployment

```bash
# See policy violation details
kubectl get policyreport -n apps -o yaml

# Temporarily set policy to Audit (not Enforce) for debugging
kubectl patch clusterpolicy require-resource-limits \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/validationFailureAction","value":"Audit"}]'

# Remember to switch back to Enforce after fixing
```

---

## Canary rollout commands

```bash
# Watch a rollout in real time
kubectl argo rollouts get rollout user-service -n apps --watch

# Manually promote a paused canary
kubectl argo rollouts promote user-service -n apps

# Abort canary and return to stable
kubectl argo rollouts abort user-service -n apps

# Retry a failed rollout
kubectl argo rollouts retry rollout user-service -n apps
```
