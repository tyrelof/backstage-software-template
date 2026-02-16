# GitLab CI/CD Pipeline

## Overview

The pipeline automates continuous integration and deployment:

1. **Lint** - Validate code, YAML, Helm charts (non-blocking)
2. **Test** - Run unit tests (non-blocking)
3. **Docs** - Generate TechDocs artifacts (non-blocking)
4. **Prep** - Create ECR repository and AWS infrastructure
5. **Build** - Create Docker image, push to ECR, security scan
6. **Release** - Auto-deploy to stage, manual approval for prod
7. **Ops** - Manual restart buttons for environments

---

## 🔄 Pipeline Stages

### 1. Lint

Validates code quality and configuration (non-blocking):

```bash
# ESLint - JavaScript/React
eslint .
✅ or ⚠️ Warning (doesn't fail pipeline)

# Helm Lint - Kubernetes manifests
helm lint charts/
✅ or ⚠️ Warning (doesn't fail pipeline)

# YAML Lint - CI/CD manifests
yamllint .
✅ or ⚠️ Warning (doesn't fail pipeline)

# npm audit - Dependency vulnerabilities
npm audit --audit-level=moderate
⚠️ Informational (doesn't fail pipeline)
```

**Fix issues locally**:
```bash
make lint        # Run locally before commit
npm audit fix    # Fix vulnerabilities
```

---

### 2. Test

Runs unit tests if `npm test` is configured (non-blocking):

```bash
npm test
```

**If tests fail**: Pipeline continues (non-blocking), but fix before production.

---

### 3. Docs

Generates TechDocs artifacts for Backstage (non-blocking):

```bash
# Builds documentation from docs/ folder
# Publishes to S3 for Backstage TechDocs
```

---

### 4. Prep

Prepares infrastructure prerequisites:

- **Creates ECR repository** if doesn't exist
- **Creates AWS SSM paths**:
  - `/${{ values.system }}/${{ values.app_name }}/stage/app`
  - `/${{ values.system }}/${{ values.app_name }}/prod/app`
- Validates AWS credentials and permissions

```bash
# Example: SSM paths created as SecureString parameters
aws ssm put-parameter \
  --name "/platform/my-app/stage/app" \
  --type "SecureString" \
  --value "{}" \
  --overwrite

aws ssm put-parameter \
  --name "/platform/my-app/prod/app" \
  --type "SecureString" \
  --value "{}" \
  --overwrite
```

---

### 5. Build

Creates Docker image and pushes to ECR:

```bash
# Build multi-stage Docker image
docker build -t my-app:latest .

# Tag with git commit SHA (immutable identifier)
docker tag my-app:latest \
  123456789.dkr.ecr.us-east-2.amazonaws.com/my-app:abc123def456

# Tag with "latest"
docker tag my-app:latest \
  123456789.dkr.ecr.us-east-2.amazonaws.com/my-app:latest

# Push both tags to ECR
docker push 123456789.dkr.ecr.us-east-2.amazonaws.com/my-app:abc123def456
docker push 123456789.dkr.ecr.us-east-2.amazonaws.com/my-app:latest
```

**Image tags**:
- `abc123def456` - Git commit SHA (unique, immutable reference)
- `latest` - Pointer to current main branch build

**Security Scanning (integrated in build)**:

```bash
# Trivy scans for CVEs and misconfigurations
trivy image 123456789.dkr.ecr.us-east-2.amazonaws.com/my-app:abc123def456

# Generate SBOM (Software Bill of Materials)
trivy sbom 123456789.dkr.ecr.us-east-2.amazonaws.com/my-app:abc123def456 \
  --format json > sbom.json
```

**Results**:
- 🟢 **Green**: No critical vulnerabilities
- 🟡 **Yellow**: Medium/low severity (non-blocking)
- 🔴 **Red**: Critical vulnerabilities (may prevent prod)

---

### 6. Release

Deploys to staging automatically, production requires approval:

#### Automatic to Staging

```bash
# 1. Image tag set in values-stage.yaml via yq
yq eval ".image.tag = \"abc123def456\"" \
  -i charts/my-app/values-stage.yaml

# 2. Commit to git
git add charts/my-app/values-stage.yaml
git commit -m "chore: bump image to abc123def456"
git push origin main

# 3. ArgoCD detects change and syncs automatically
argocd app sync my-app-stage --wait
```

**Namespace**: `${{ values.app_name }}-stage` (e.g., `my-app-stage`)  
**ArgoCD app**: `my-app-stage`

#### Manual to Production

```bash
# 1. Click ▶️ Play button in GitLab UI
# 2. Same process as staging:
yq eval ".image.tag = \"abc123def456\"" \
  -i charts/my-app/values-prod.yaml

# 3. Commit and push
git add charts/my-app/values-prod.yaml
git commit -m "chore: bump prod image to abc123def456"
git push origin main

# 4. ArgoCD app syncs
argocd app sync my-app-prod --wait
```

**Namespace**: `${{ values.app_name }}-prod` (e.g., `my-app-prod`)  
**ArgoCD app**: `my-app-prod`

---

## ✅ Deployment Checklist

**Before production deployment**:

- [ ] All lint checks passed (or at least acknowledged)
- [ ] Tests passing or deliberately skipped
- [ ] Docker image built and scanned for CVEs
- [ ] Image pushed to ECR successfully
- [ ] Staging deployment is stable and healthy
- [ ] Health checks passing (`/health` returns 200)
- [ ] Recent logs show no errors
- [ ] Team approval obtained (if required)

**Production approval criteria**:

- ✅ Staging deployed successfully for 15+ minutes
- ✅ Health checks passing in staging
- ✅ Logs showing normal operation
- ✅ No recent error spikes
- ✅ Team available for quick rollback if needed

---

## 🎮 Manual Operations (Ops Stage)

Manual restart buttons available after successful deploy:

```bash
# Restart staging deployment
kubectl -n ${{ values.app_name }}-stage rollout restart deployment/${{ values.app_name }}

# Restart production deployment (requires approval)
kubectl -n ${{ values.app_name }}-prod rollout restart deployment/${{ values.app_name }}
```

Use cases:
- Restart after secrets updated in SSM
- Force pods to pick up new config
- Recover from temporary database connection issues

---

## 🔍 Pipeline Permissions & Access

| Role | Lint | Test | Build | Deploy Stage | Deploy Prod | Restart |
|------|------|------|-------|--------------|------------|---------|
| **Developer** | ✅ | ✅ | ✅ | 🔄 Auto | ❌ Manual | ✅ Stage only |
| **Tech Lead** | ✅ | ✅ | ✅ | 🔄 Auto | ✅ Approve | ✅ All |
| **DevOps** | ✅ | ✅ | ✅ | 🔄 Auto | ✅ Approve | ✅ All |

**Auto-deploy to stage**: Anyone can merge to `main`. Deployment happens automatically.  
**Manual deploy to prod**: Only approved roles can trigger production deployment.

---

## 📊 Common Deployment Patterns

### Pattern 1: Regular Feature Release

```
1. Developer creates feature branch from main
2. Pushes commits → Pipeline runs lint/test
3. Creates merge request
4. Approvers review code
5. Merges to main → Builds image, auto-deploys to stage
6. Tests in stage environment
7. Clicks deploy button → Prod deployment (requires approval)
8. ArgoCD deploys to prod namespace
```

### Pattern 2: Hotfix to Production

```
1. Create hotfix branch from main
2. Fix the issue
3. Merge to main → Auto-deploys to stage
4. Quick validation in stage
5. Deploy to prod immediately (approval required)
6. Monitor prod deployment
```

### Pattern 3: Configuration Change Only (No Code)

```
1. Edit Helm values (e.g., LOG_LEVEL)
2. Commit values-stage.yaml
3. Push to main
4. ArgoCD auto-updates (Helm change triggers Prep stage)
5. No Docker build needed (reuses existing image)
```

---

## 🔧 CI/CD Configuration

### GitLab CI (`.gitlab-ci.yml`)

Includes all stage definitions from `ci/` folder:

```yaml
include:
  - local: 'ci/00-base.yml'
  - local: 'ci/10-lint.yml'
  - local: 'ci/20-test.yml'
  - local: 'ci/25-docs.yml'
  - local: 'ci/30-prep.yml'
  - local: 'ci/40-build.yml'
  - local: 'ci/50-release.yml'
  - local: 'ci/60-ops.yml'
```

### Helm Values (Environment-Specific)

**values-stage.yaml**:
```yaml
config:
  APP_ENV: "stage"
  NODE_ENV: "stage"
  LOG_LEVEL: "debug"

replicaCount: 1
refreshInterval: 5m
```

**values-prod.yaml**:
```yaml
config:
  APP_ENV: "production"
  NODE_ENV: "production"
  LOG_LEVEL: "info"

replicaCount: 3
refreshInterval: 1h
deletionPolicy: "Retain"
```

---

## 🚨 Troubleshooting

### Pipeline Fails at Prep Stage

ECR or SSM creation failed:

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify IAM permissions
aws iam get-role-policy --role-name ci-runner-role --policy-name AllowECR

# Manual ECR creation
aws ecr create-repository \
  --repository-name my-app \
  --region us-east-2

# Manual SSM creation
aws ssm put-parameter \
  --name "/platform/my-app/stage/app" \
  --type SecureString \
  --value '{}' \
  --region us-east-2
```

### Pipeline Fails at Build/Push

Docker or ECR authentication issue:

```bash
# Verify ECR login
aws ecr get-login-password | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-2.amazonaws.com

# Check image build locally
docker build -t my-app:test .

# Verify Dockerfile is correct
cat Dockerfile | head -20
```

### Deployment Stuck in Release Stage

ArgoCD not syncing:

```bash
# Check ArgoCD app status
argocd app get my-app-stage

# Force ArgoCD refresh
argocd app sync my-app-stage --force

# Check if namespace exists
kubectl get namespace my-app-stage
```

### Pods Not Starting After Deploy

Check deployment logs:

```bash
# View pod status
kubectl -n ${{ values.app_name }}-stage get pods

# View pod events
kubectl -n ${{ values.app_name }}-stage describe pod <pod-name>

# View application logs
kubectl -n ${{ values.app_name }}-stage logs deployment/${{ values.app_name }}

# Check if secrets loaded
kubectl -n ${{ values.app_name }}-stage exec <pod-name> -- env | grep DB_
```

---

## 📈 Pipeline Performance

### Typical Execution Times

| Stage | Duration | Notes |
|-------|----------|-------|
| **Lint** | 1-2 min | ESLint, Helm lint, YAML |
| **Test** | 2-5 min | Jest unit tests |
| **Docs** | 1-2 min | MkDocs build |
| **Prep** | 1-2 min | ECR/SSM verification |
| **Build** | 5-10 min | Docker build, push, scan |
| **Release** | 2-3 min | Helm update, Git commit |
| **Total** | **12-25 min** | Full pipeline time |

### Optimization Tips

```bash
# Use Docker layer caching
# - Multi-stage builds (dev, prod)
# - Optimal layer ordering (dependencies first)

# Parallelize jobs where possible
# - Lint and test can run simultaneously
# - Multiple workers for concurrent builds

# Cache dependencies
# - npm packages cached between builds
# - Docker image layers cached
```

---

## 📚 Reference

| Variable | Value | Used In |
|----------|-------|---------|
| `CI_COMMIT_SHA` | `abc123def456` | Image tag, logs |
| `CI_PROJECT_PATH_SLUG` | `project-name` | ECR repo name |
| `CI_ENVIRONMENT_NAME` | `production` | Deployment target |
| `DEST_NS` | `my-app-prod` | Kubernetes namespace |
| `ARGO_APP` | `my-app-prod` | ArgoCD app name |

---

## 🔗 Related

- See [deployment.md](deployment.md) for manual Helm commands
- See [kubernetes.md](kubernetes.md) for kubectl debugging
- See [secrets.md](secrets.md) for SSM parameter management

