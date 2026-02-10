# GitLab CI/CD Pipeline

The GitLab CI/CD pipeline automates platform prerequisites, testing, building, and deployment of the FastAPI service using ArgoCD for GitOps-based deployments.

## Pipeline Stages

### 1. Prep (Stage: 30-prep.yml)
- **platform_prereqs**: Creates AWS ECR repository if it doesn't exist
  - Enables image scanning on push for security
  - Self-service: developers don't need to manually create repos
- **platform_ssm_placeholders**: Creates AWS SSM parameters for secrets
  - Creates `/${SYSTEM}/${APP_NAME}/stage/app` - staging secrets placeholder
  - Creates `/${SYSTEM}/${APP_NAME}/prod/app` - production secrets placeholder
  - Uses SecureString type for encrypted storage
  - Allows operators to populate secrets via AWS SSM console or CLI

### 2. Lint (Stage: 10-lint.yml)
- Code quality checks using **ruff**
- Code formatting verification with **black**
- Import sorting with **isort**
- Allows failure to not block pipeline

### 3. Test (Stage: 20-tests.yml)
- Unit tests using **pytest**
- Code coverage reporting
- Coverage artifacts stored for analysis
- Allows failure but provides metrics

### 4. Build (Stage: 30-build.yml) - `ci_build_image`
- Docker image build (runs once per commit) using BuildKit
- Depends on: `platform_prereqs`, `platform_ssm_placeholders` (ensures ECR repo exists)
- Pushes to AWS ECR with tag `$COMMIT_ID` (short SHA)
- Tags as `latest` for quick reference
- **Key**: Image is built once and reused for all environments

### 5. Release (Stage: 40-release.yml) - `cd_stage_deploy`
- **Automatic** deployment to staging (only if src/, Dockerfile, or requirements.txt changed)
- Updates `charts/${APP_NAME}/values-stage.yaml` with new image tag
- Registers/updates ArgoCD application for staging
- Syncs application with ArgoCD
- **Same image** from build stage is deployed

### 6. Operations (Stage: 50-ops.yml)
- **Production deployment** (`cd_prod_deploy`) - **Manual approval required**
  - Triggered after staging deployment succeeds
  - Updates `charts/values-prod.yaml` with **same image tag** as staging
  - Deploys to production via ArgoCD
  - Requires manual trigger in GitLab UI
- **Manual operations** available:
  - `ops_restart_stage` - Restart staging deployment
  - `ops_restart_prod` - Restart production deployment (requires confirmation)

## Deployment Workflow

```
Commit to main
    ↓
Prep (ECR repo + SSM placeholders)
    ↓
Lint → Test → Build image (once via BuildKit)
                ↓
            Staging deployment (automatic if code changed)
                ↓
            Production deployment (manual, same image)
                ↓
            Operations (restart buttons)
```

### Key Benefits

1. **Self-Service Platform**: ECR repo and SSM parameters auto-created on first deploy
2. **Single Build**: Image built once via BuildKit and promoted through environments
3. **Same Code**: Staging and production run identical image (only config differs)
4. **ArgoCD Integration**: GitOps-based deployment with version control
5. **Manual Promotion**: Production requires explicit approval (manual trigger)
6. **Staged Testing**: Changes tested in staging before production
7. **Fast Rollback**: Easy rollback via ArgoCD if issues arise
8. **Encrypted Secrets**: SSM SecureString storage for app configuration

## Environment Variables

Required CI/CD variables in GitLab:

```
AWS_ACCOUNT_ID          # Your AWS account ID
AWS_REGION              # AWS region (e.g., us-east-2)
AWS_ECR_REGISTRY        # ECR registry (e.g., 123456789.dkr.ecr.us-east-2.amazonaws.com)
SYSTEM                  # System name for SSM paths (e.g., popapps)
CI_REGISTRY_USER        # GitLab registry username (for caching)
CI_REGISTRY_PASSWORD    # GitLab registry password (for caching)
PROJECT_PUSH_TOKEN      # GitLab push token for Git operations
ARGOCD_USERNAME         # ArgoCD username (default: admin)
ARGOCD_PASSWORD         # ArgoCD password
```

## SSM Secrets Structure

The pipeline creates SSM parameters in this structure:

```
/${SYSTEM}/${APP_NAME}/stage/app   → Staging app secrets (JSON)
/${SYSTEM}/${APP_NAME}/prod/app    → Production app secrets (JSON)
```

**Example**: Populate via AWS CLI:

```bash
aws ssm put-parameter \
  --name "/popapps/myapp/stage/app" \
  --type "SecureString" \
  --value '{"DB_PASSWORD":"secret123"}' \
  --overwrite
```

## Pipeline Configuration

Main pipeline file: `.gitlab-ci.yml`

Includes modular CI files:
- `ci/00-base.yml` - Base variables and caching
- `ci/10-lint.yml` - Code quality checks
- `ci/20-tests.yml` - Unit testing
- `ci/30-prep.yml` - Platform prerequisites (ECR repo, SSM placeholders)
- `ci/30-build.yml` - Docker build via BuildKit and push to ECR
- `ci/40-release.yml` - Stage deployment via ArgoCD
- `ci/50-ops.yml` - Production deployment and manual operations

## How It Works

### Build Stage

```yaml
ci_build_image:
  script:
    - docker build -t $IMAGE_REPO:$COMMIT_ID .
    - docker push $IMAGE_REPO:$COMMIT_ID
```

Image is tagged with commit SHA and pushed to AWS ECR.

### Staging Deployment

```yaml
cd_stage_deploy:
  script:
    # Update staging values with new image tag
    yq -i '.image.tag = strenv(COMMIT_ID)' "charts/${APP_NAME}/values-stage.yaml"
    
    # Commit updated values
    git commit -m "chore: image=...:${COMMIT_ID} (stage)"
    git push origin main
    
    # Create/update ArgoCD application
    argocd app create|set "${APP_NAME}-stage" ...
    
    # Sync with ArgoCD
    argocd app sync "${APP_NAME}-stage" --wait
```

### Production Deployment

```yaml
cd_prod_deploy:
  when: manual  # Requires manual approval in GitLab UI
  script:
    # Update production values with SAME image tag
    yq -i '.image.tag = strenv(COMMIT_ID)' "charts/${APP_NAME}/values-prod.yaml"
    
    # Same workflow as staging
    # ArgoCD creates/updates and syncs prod application
```

## Manual Approval Process

### Promoting to Production

1. Go to GitLab project → **CI/CD** → **Pipelines**
2. Find the pipeline for your commit (should show staging is deployed)
3. Scroll down to **Operations** section
4. Click **Play** button on `cd_prod_deploy` job
5. Confirm deployment

### After Deployment

ArgoCD will automatically sync the application. Monitor:

```bash
# Check ArgoCD sync status
argocd app get ${APP_NAME}-prod

# Check Kubernetes deployment
kubectl rollout status deployment/${APP_NAME} -n ${APP_NAME}-prod

# View logs
kubectl logs -f -l app=${APP_NAME} -n ${APP_NAME}-prod
```

## Image Promotion Example

**Scenario**: Fix a bug, test in staging, promote to production

1. **Push code** to main branch
2. **Pipeline runs**:
   - Lint and test pass ✓
   - Docker image built: `123456.dkr.ecr.us-east-2.amazonaws.com/my-app:abc1234` ✓
   - Staging values updated → deployment automatic ✓
3. **Test in staging**: `https://my-app.stage.popapps.ai`
4. **Manual approval**: Click play on `cd_prod_deploy` in GitLab
5. **Production deploys**: Same `abc1234` image with production config

## Troubleshooting

### Build Failed
- Check Docker build logs in GitLab CI/CD
- Verify base image availability
- Check dependency installation: `pip install -r requirements.txt`

### Staging Deployment Failed
- Check ArgoCD credentials: `ARGOCD_PASSWORD`
- Verify git credentials: `PROJECT_PUSH_TOKEN`
- Check if ArgoCD can access repository

### Production Deployment Not Showing
- Staging deployment must succeed first
- Production job only appears after `cd_stage_deploy` completes
- Click **Play** button to manually trigger

### Same Image in Both Environments
- This is by design! Only config differs between environments
- Different resource limits, replicas, etc. in values-stage.yaml vs values-prod.yaml
- Same code/image ensures consistency
