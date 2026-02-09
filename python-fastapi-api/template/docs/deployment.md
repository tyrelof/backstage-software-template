# Deployment Guide

Step-by-step guide for deploying ${{ values.app_name }} to production using GitOps with ArgoCD.

## Prerequisites

- GitLab repository configured
- AWS account with EKS cluster
- ArgoCD deployed on EKS cluster
- kubectl configured for EKS cluster
- Helm 3.x installed (for local testing)

## Deployment Architecture

The deployment uses a **GitOps** workflow:

```
Git Repository (main branch)
    ↓
GitLab CI/CD Pipeline
    ├─ Build: Docker image → AWS ECR
    ├─ Stage: ArgoCD updates staging deployment
    └─ Prod: Manual → ArgoCD updates production deployment
```

All deployment state is stored in Git (`charts/values-stage.yaml`, `charts/values-prod.yaml`), enabling:
- Full audit trail of changes
- Easy rollback via Git history
- Consistent deployment process
- Declarative infrastructure

## Quick Start

### For Developers

1. **Commit code to main**:
   ```bash
   git add .
   git commit -m "feat: add new endpoint"
   git push origin main
   ```

2. **Pipeline automatically**:
   - ✓ Lints and tests code
   - ✓ Builds Docker image
   - ✓ Deploys to staging
   - ✓ Waits for manual approval

3. **Test in staging**:
   ```bash
   # Access staging environment
   curl https://${{ values.app_name }}.stage.${{ values.base_domain }}/health
   ```

4. **Promote to production** (manual):
   - Go to GitLab → Pipelines → Find your commit
   - Click **Play** on `cd_prod_deploy` job
   - Confirm deployment

### For Operators

#### Set Up New Service

1. **Prepare environment variables** in GitLab CI/CD settings:
   ```
   AWS_ACCOUNT_ID: 123456789012
   AWS_REGION: us-east-2
   PROJECT_PUSH_TOKEN: glpat-xxxxxxxxxxxxx
   ARGOCD_USERNAME: admin
   ARGOCD_PASSWORD: xxxxxxxxxxxxxxxx
   ```

2. **Deploy service**:
   - Push code to main → Pipeline runs → Staging deployed automatically
   - Manual approval → Production deployed

3. **Monitor deployment**:
   ```bash
   argocd app get ${{ values.app_name }}-stage
   argocd app get ${{ values.app_name }}-prod
   ```

## Detailed Deployment Process

### Stage 1: Lint and Test

```
Triggered by: Commit to main branch
Actions:
  - Lint code (ruff, black, isort)
  - Run unit tests with coverage
  - No deployment happens yet
```

### Stage 2: Build Docker Image

```
Triggered by: Lint and test pass
Actions:
  - Build Docker image
  - Tag with commit SHA (e.g., abc1234)
  - Push to AWS ECR
  - Image: ${{ values.image_repository }}:abc1234
  - Also tagged as 'latest'
```

### Stage 3: Deploy to Staging

```
Triggered by: Build succeeds + code files changed
Actions:
  - Update: charts/${{ values.app_name }}/values-stage.yaml
  - Commit updated values to Git
  - Create/update ArgoCD app: ${{ values.app_name }}-stage
  - Sync application (auto-deploy)
```

**Accessible at**: `https://${{ values.app_name }}.stage.${{ values.base_domain }}`

### Stage 4: Manual Approval → Production

```
Triggered by: Manual click in GitLab UI
Actions:
  - Update: charts/${{ values.app_name }}/values-prod.yaml
  - SAME image tag as staging
  - Commit updated values to Git
  - Create/update ArgoCD app: ${{ values.app_name }}-prod
  - Sync application (auto-deploy)
```

**Accessible at**: `https://${{ values.app_name }}.${{ values.base_domain }}`

## Monitoring Deployments

### Real-time Status

```bash
# Check staging deployment
argocd app get ${{ values.app_name }}-stage --refresh

# Check production deployment
argocd app get ${{ values.app_name }}-prod --refresh

# Watch sync progress
argocd app wait ${{ values.app_name }}-prod --timeout 300
```

### View Logs

```bash
# Stream logs from staging
kubectl logs -f -l app=${{ values.app_name }} -n ${{ values.app_name }}-stage

# Stream logs from production
kubectl logs -f -l app=${{ values.app_name }} -n ${{ values.app_name }}-prod
```

### Health Checks

```bash
# Test staging health endpoints
curl https://${{ values.app_name }}.stage.${{ values.base_domain }}/health
curl https://${{ values.app_name }}.stage.${{ values.base_domain }}/api/v1/status

# Test production health endpoints
curl https://${{ values.app_name }}.${{ values.base_domain }}/health
curl https://${{ values.app_name }}.${{ values.base_domain }}/api/v1/status
```

## Configuration Differences Between Environments

### Staging (values-stage.yaml)

```yaml
replicaCount: 1                    # Minimal replicas
autoscaling:
  minReplicas: 1
  maxReplicas: 3                  # Small scaling range
resources:
  requests:
    cpu: 50m                       # Light resources
    memory: 64Mi
  limits:
    cpu: 250m
    memory: 256Mi
```

### Production (values-prod.yaml)

```yaml
replicaCount: 2                    # Higher replicas
autoscaling:
  minReplicas: 2
  maxReplicas: 10                 # Larger scaling range
resources:
  requests:
    cpu: 100m                      # More resources
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Code/Image**: Identical in both environments

## Rollback Procedure

### Via ArgoCD

```bash
# View deployment history
argocd app history ${{ values.app_name }}-prod

# Rollback to previous sync
argocd app rollback ${{ values.app_name }}-prod <revision>
```

### Via Git

```bash
# Revert last commit
git revert HEAD
git push origin main
# Pipeline runs → Staging deploys → Manual approval → Production deploys
```

### Emergency Rollback

```bash
# Edit values directly (not recommended, use Git instead)
kubectl set image deployment/${{ values.app_name }} \
  ${{ values.app_name }}=${{ values.image_repository }}:previous-tag \
  -n ${{ values.app_name }}-prod
```

## Post-Deployment Verification

### 1. Check Pod Status

```bash
kubectl get pods -n ${{ values.app_name }}-prod
```

Expected: All pods `Running` and `Ready`

### 2. Check Rollout Status

```bash
kubectl rollout status deployment/${{ values.app_name }} \
  -n ${{ values.app_name }}-prod
```

Expected: "deployment "${{ values.app_name }}" successfully rolled out"

### 3. Test Application

```bash
# GET health endpoint
curl -v https://${{ values.app_name }}.${{ values.base_domain }}/health

# GET status endpoint
curl -v https://${{ values.app_name }}.${{ values.base_domain }}/api/v1/status

# Access interactive docs
open https://${{ values.app_name }}.${{ values.base_domain }}/docs
```

### 4. Monitor Metrics

Check Grafana dashboard: `https://grafana.popapps.ai`

## Troubleshooting

### Deployment Stuck in Pending

```bash
# Check ArgoCD status
argocd app get ${{ values.app_name }}-prod

# Check if app is syncing
argocd app wait ${{ values.app_name }}-prod --timeout 300 || argocd app sync ${{ values.app_name }}-prod --force
```

### Pod CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n ${{ values.app_name }}-prod

# Check events
kubectl describe pod <pod-name> -n ${{ values.app_name }}-prod

# Check resource limits
kubectl top pod <pod-name> -n ${{ values.app_name }}-prod
```

### Cannot Connect to Application

```bash
# Check ingress
kubectl get ingress -n ${{ values.app_name }}-prod

# Check service
kubectl get svc -n ${{ values.app_name }}-prod

# Test DNS
kubectl exec -it <pod-name> -n ${{ values.app_name }}-prod -- \
  curl http://localhost:${{ values.service_port }}/health
```

### ArgoCD Application Not Found

```bash
# List all applications
argocd app list

# Check if app exists in correct ArgoCD instance
argocd app get ${{ values.app_name }}-prod --refresh
```

## CI/CD Variables Reference

Set these in GitLab project → Settings → CI/CD → Variables:

| Variable | Purpose |
|----------|---------|
| `AWS_ACCOUNT_ID` | AWS account for ECR |
| `AWS_REGION` | AWS region for ECR |
| `CI_REGISTRY_USER` | GitLab registry username |
| `CI_REGISTRY_PASSWORD` | GitLab registry token |
| `PROJECT_PUSH_TOKEN` | GitLab token for Git operations |
| `ARGOCD_USERNAME` | ArgoCD login username |
| `ARGOCD_PASSWORD` | ArgoCD login password |

## Support

For issues or questions:
- Check GitLab pipeline logs
- Check ArgoCD application status
- Check Kubernetes events: `kubectl describe`
- View application logs: `kubectl logs`
- Slack: #deployment-support
