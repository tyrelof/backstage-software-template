# Deployment Guide

## Overview

This application follows the **platform delivery model**:

1. **Develop locally** - Use `make dev` or native Node.js
2. **Commit to Git** - Push to `main` branch
3. **CI builds image** - GitLab CI creates Docker image and pushes to ECR
4. **ArgoCD deploys** - GitOps automatically deploys to stage or waits for manual approval to prod
5. **Monitor & rollback** - Watch health checks and metrics

**You do not run kubectl apply or helm upgrade manually.**

---

## 🔄 Deployment Workflow

### 1. Local Development

```bash
# Start development server
make dev

# Make changes
# Commit and push
git add .
git commit -m "Add new feature"
git push origin main
```

### 2. CI Build (Automatic)

When you push to `main`, the GitLab pipeline:

- ✅ **Lint**: ESLint, Helm lint, YAML validation
- ✅ **Test**: npm test (if configured)
- ✅ **Build**: BuildKit multi-stage Docker build
- ✅ **Push**: Image pushed to ECR with tags: commit SHA, `latest`
- ✅ **Security**: Trivy vulnerability scan
- ✅ **Release**: Auto-deploy to stage

### 3. Staging Validation

After build, the pipeline automatically deploys to **stage** namespace `${{ values.app_name }}-stage`:

```bash
# Check deployment status
kubectl -n ${{ values.app_name }}-stage get deployment ${{ values.app_name }}

# View logs
kubectl -n ${{ values.app_name }}-stage logs -f deployment/${{ values.app_name }}

# Test in stage
curl https://${{ values.app_name }}-stage.example.com/health
```

### 4. Production Deploy (Manual)

Once validated in stage, **you** trigger production deploy:

- Via GitLab CI: Click **Play** on the "deploy-prod" job
- Via ArgoCD UI: Sync the production application
- Via CLI:

```bash
argocd app sync ${{ values.app_name }}-prod --wait
```

### 5. Monitor Production

After deploy to production namespace `${{ values.app_name }}-prod`:

```bash
# Check pod status
kubectl -n ${{ values.app_name }}-prod get pods -l app=${{ values.app_name }}

# Watch logs (real-time)
kubectl -n ${{ values.app_name }}-prod logs -f deployment/${{ values.app_name }}

# View metrics
# (via Grafana/Prometheus dashboard)
```

---

## 📦 Image Tagging & Versioning

Images are pushed to ECR with:

| Tag | Purpose |
|-----|---------|
| `latest` | Current main branch build (latest commit)|
| `{commit-sha}` | Full git commit SHA (e.g., `abc123def456`) |
| `v1.0.0` | Optional semantic version tag (manual) |

The CI/CD pipeline automatically updates Helm `values-stage.yaml` and `values-prod.yaml` with the commit SHA when building:

```bash
# values-stage.yaml
image:
  repository: 123456789.dkr.ecr.us-east-2.amazonaws.com/my-app
  tag: "abc123def456"  # CI automatically updates this
```

---

## 🚀 Staging to Production Promotion

### Requirements

Before promoting to production:

```bash
# 1. Verify stage deployment is healthy
kubectl -n ${{ values.app_name }}-stage get pods

# 2. Check recent logs for errors
kubectl -n ${{ values.app_name }}-stage logs deployment/${{ values.app_name }} --tail 50

# 3. Verify liveness/readiness probes passing
kubectl -n ${{ values.app_name }}-stage describe pod <pod-name> | grep -A 5 "Liveness\|Readiness"

# 4. Verify health endpoint
kubectl -n ${{ values.app_name }}-stage port-forward svc/${{ values.app_name }} 3000:3000 &
curl http://localhost:3000/health && kill %1
```

### Production Deploy Steps

```bash
# 1. Go to GitLab: CI/CD > Pipelines > Your Build
# 2. Find "deploy-prod" job (manual trigger)
# 3. Click ▶️ Play button
# 4. Wait for deployment to complete

# Or via CLI:
argocd app sync ${{ values.app_name }}-prod --wait
```

### Post-Deployment Validation

```bash
# 1. Check pods are running
kubectl -n ${{ values.app_name }}-prod get pods

# 2. Monitor logs
kubectl -n ${{ values.app_name }}-prod logs -f deployment/${{ values.app_name }}

# 3. Test health endpoint
kubectl -n ${{ values.app_name }}-prod port-forward svc/${{ values.app_name }} 3000:3000 &
curl http://localhost:3000/health && kill %1

# 4. Monitor metrics (use Grafana/Prometheus/CloudWatch)
# Watch for spike in errors, latency, or resource usage
```

---

## 🔄 Rollback Procedures

### Quick Rollback (Last Image)

```bash
# View release history
helm history ${{ values.app_name }} -n ${{ values.app_name }}-prod

# Rollback to previous release
helm rollback ${{ values.app_name }} -n ${{ values.app_name }}-prod

# Watch rollback progress
kubectl -n ${{ values.app_name }}-prod rollout status deployment/${{ values.app_name }}
```

### Rollback via ArgoCD

```bash
# View deployment history
argocd app history ${{ values.app_name }}-prod

# Rollback to specific revision
argocd app rollback ${{ values.app_name }}-prod 1

# Monitor sync
argocd app wait ${{ values.app_name }}-prod
```

### Manual Rollback (Emergency)

```bash
# Edit values-prod.yaml to previous image SHA
nano charts/${{ values.app_name }}/values-prod.yaml

# Update image.tag to known-good commit
# image:
#   tag: "previous-good-sha"

# Commit and push
git add charts/${{ values.app_name }}/values-prod.yaml
git commit -m "hotfix: rollback prod to previous image"
git push origin main

# ArgoCD auto-syncs
# Alternatively, force sync immediately:
argocd app sync ${{ values.app_name }}-prod --force
```

---

## 🛠️ Helm Update (Config Changes Only)

If you update Helm values without changing code:

```bash
# 1. Edit values file
nano charts/${{ values.app_name }}/values-stage.yaml

# 2. Test locally
helm template ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -f values-stage.yaml > /tmp/rendered.yaml

# 3. Commit and push
git add charts/${{ values.app_name }}/values-stage.yaml
git commit -m "chore: update staging replicas and resources"
git push origin main

# 4. ArgoCD detects change and syncs automatically
# Note: No Docker rebuild needed - reuses existing image
```

---

## 🔔 Deployment Notifications

Monitor deployment in real-time:

```bash
# Watch pod rollout progress
kubectl -n ${{ values.app_name }}-stage rollout status deployment/${{ values.app_name }} -w

# Get event stream
kubectl -n ${{ values.app_name }}-stage get events -w

# Check ArgoCD sync status
argocd app wait ${{ values.app_name }}-stage --health
```

---

## 🚨 Common Issues

### Pods Stuck in ImagePullBackOff

```bash
# 1. Verify image exists in ECR
aws ecr describe-images --repository-name ${{ values.app_name }} --region us-east-2

# 2. Check pod events
kubectl -n ${{ values.app_name }}-stage describe pod <pod-name>

# 3. Verify image.repository in values
kubectl -n ${{ values.app_name }}-stage get deployment ${{ values.app_name }} -o yaml | grep image:
```

### Pods Stuck in CrashLoopBackOff

```bash
# 1. Check application error
kubectl -n ${{ values.app_name }}-stage logs <pod-name> --previous

# 2. Verify environment variables loaded
kubectl -n ${{ values.app_name }}-stage exec <pod-name> -- printenv | grep DB_

# 3. Check if database/dependencies accessible
kubectl -n ${{ values.app_name }}-stage exec <pod-name> -- curl http://postgres:5432
```

### Deployment Timeout

```bash
# 1. Check pod status
kubectl -n ${{ values.app_name }}-stage get pods -o wide

# 2. View resource constraints
kubectl describe node | grep -A 5 "Allocated resources"

# 3. Increase resource limits if needed
helm upgrade ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }}-stage \
  --set resources.requests.memory=256Mi
```

---

## 📊 Environment Comparison

| Aspect | Stage | Production |
|--------|-------|------------|
| **Replicas** | 1 | 3+ |
| **Resources** | Small | Large |
| **Updates** | Any time | Scheduled |
| **Secrets** | Test data | Real (encrypted) |
| **Backup** | No | Yes |
| **Monitoring** | Basic | Comprehensive |
| **Auto-scale** | No | Yes (if HPA enabled) |

---

## 📚 Reference Commands

```bash
# Deploy info
helm list -n ${{ values.app_name }}-stage
helm status ${{ values.app_name }} -n ${{ values.app_name }}-stage
helm get values ${{ values.app_name }} -n ${{ values.app_name }}-stage

# Kubernetes info
kubectl get all -n ${{ values.app_name }}-stage
kubectl describe deployment ${{ values.app_name }} -n ${{ values.app_name }}-stage
kubectl get events -n ${{ values.app_name }}-stage --sort-by='.lastTimestamp'

# ArgoCD info
argocd app get ${{ values.app_name }}-stage
argocd app get ${{ values.app_name }}-prod
```

See [kubernetes.md](kubernetes.md) for more kubectl debugging commands.

