# Make your GitLab + Backstage flow feel like your GitHub setup. Here’s the ECR-ready recipe you can drop in now, with two auth modes:

## A) IRSA (best) — no static keys, Kaniko “just pushes”

One-time (cluster):

### 1. Create IAM role for job pods (trust EKS OIDC) with ECR push perms:
```json
{
  "Version":"2012-10-17",
  "Statement":[{"Effect":"Allow","Action":[
    "ecr:GetAuthorizationToken","ecr:BatchCheckLayerAvailability","ecr:CompleteLayerUpload",
    "ecr:BatchGetImage","ecr:InitiateLayerUpload","ecr:PutImage","ecr:UploadLayerPart",
    "ecr:DescribeRepositories","ecr:ListImages","ecr:CreateRepository"
  ],"Resource":"*"}]
}
```

### 2. Create a ServiceAccount for job pods and annotate with that role:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-job-sa
  namespace: gitlab-runner
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/<ECRPushRole>
```

### 3. Tell the GitLab Runner to use it for jobs (Helm values):
```yaml
runners:
  kubernetes:
    serviceAccountName: gitlab-job-sa
```

.gitlab-ci.yml (ECR version):

```yaml
stages: [prepare, build, tag, deploy]

variables:
  APP_NAME: "${{ values.app_name }}"
  APP_ENV:  "${{ values.app_env }}"
  AWS_REGION: ap-southeast-1            # <— set yours
  AWS_ACCOUNT_ID: "123456789012"        # <— set yours
  ECR_REGISTRY: "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  IMAGE_REPO: "${ECR_REGISTRY}/${APP_NAME}"
  COMMIT_ID: "${CI_COMMIT_SHORT_SHA}"

# 1) Create ECR repo if missing (idempotent)
prepare-ecr:
  stage: prepare
  tags: ["self-hosted"]
  image: public.ecr.aws/aws-cli/aws-cli:2
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  script: |
    aws --region "$AWS_REGION" ecr describe-repositories --repository-names "$APP_NAME" \
    || aws --region "$AWS_REGION" ecr create-repository --repository-name "$APP_NAME"

# 2) Build & push with Kaniko (IRSA = no creds needed)
build:
  stage: build
  tags: ["self-hosted","kaniko"]
  needs: ["prepare-ecr"]
  image: { name: gcr.io/kaniko-project/executor:debug, entrypoint: [""] }
  variables:
    AWS_REGION: $AWS_REGION
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      changes:
        - "src/**/*"
        - "Dockerfile"
        - "requirements.txt"
        - "charts/**/*"
  script: |
    /kaniko/executor \
      --context "${CI_PROJECT_DIR}" \
      --dockerfile "${CI_PROJECT_DIR}/Dockerfile" \
      --destination "${IMAGE_REPO}:${COMMIT_ID}" \
      --destination "${IMAGE_REPO}:latest" \
      --cache=true \
      --cache-repo "${IMAGE_REPO}"
    echo "COMMIT_ID=${COMMIT_ID}" >> build.env
  artifacts:
    reports: { dotenv: build.env }
    expire_in: 1 day

# 3) Tag Helm values to use the new image+tag
tag-values:
  stage: tag
  tags: ["self-hosted"]
  image: alpine:3.20
  needs: ["build"]
  rules: [ { if: '$CI_COMMIT_BRANCH == "main"' } ]
  before_script:
    - apk add --no-cache git yq
    - git config --global safe.directory "$CI_PROJECT_DIR"
    - git config user.name "Platform Bot"
    - git config user.email "platform-bot@noreply.local"
    - git remote set-url origin "https://oauth2:${PROJECT_PUSH_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git"
    - git fetch --all
    - git checkout "$CI_COMMIT_REF_NAME"
  script: |
    FILE="charts/${APP_NAME}/values-${APP_ENV}.yaml"
    yq -i '.image.repository = strenv(IMAGE_REPO)' "$FILE"
    yq -i '.image.tag = strenv(COMMIT_ID)' "$FILE"
    git add "$FILE"
    git commit -m "chore: image=${IMAGE_REPO}:${COMMIT_ID} (${APP_ENV})" || true
    git push origin "$CI_COMMIT_REF_NAME"

# 4) Deploy via Argo CD
deploy:
  stage: deploy
  tags: ["self-hosted"]
  needs: ["tag-values"]
  image: alpine:3.20
  rules: [ { if: '$CI_COMMIT_BRANCH == "main"' } ]
  before_script:
    - apk add --no-cache curl bash grep
    - curl -ksSL -o /usr/local/bin/argocd https://raw.githubusercontent.com/argoproj/argo-cd/stable/dist/argocd-linux-amd64
    - chmod +x /usr/local/bin/argocd
  script: |
    argocd login argocd-server.argocd --insecure --grpc-web \
      --username "${ARGOCD_USERNAME:-admin}" --password "$ARGOCD_PASSWORD"
    REPO_URL="${CI_REPOSITORY_URL}"
    argocd repo list | grep -q "$REPO_URL" || argocd repo add "$REPO_URL" \
      --username oauth2 --password "$PROJECT_PUSH_TOKEN"
    CHART_PATH="charts/${APP_NAME}"
    VALUES_FILE="values-${APP_ENV}.yaml"
    argocd app get "${APP_NAME}" >/dev/null 2>&1 || argocd app create "${APP_NAME}" \
      --repo "$REPO_URL" --path "$CHART_PATH" \
      --dest-namespace "$APP_ENV" --dest-server https://kubernetes.default.svc \
      --values "$VALUES_FILE" --revision "$CI_COMMIT_BRANCH" \
      --sync-policy manual --sync-option CreateNamespace=true
    argocd app sync "${APP_NAME}"
    argocd app wait "${APP_NAME}" --timeout 180
```
Pulling in cluster: EKS worker node role must have ECR read perms (usually AmazonEC2ContainerRegistryReadOnly). Then your pods can pull from ECR without imagePullSecrets.

## B) Static keys (works anywhere; rotate later)
If you can’t wire IRSA yet, set masked CI vars: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (and AWS_SESSION_TOKEN if using STS), plus AWS_REGION. Keep the same pipeline; Kaniko will use those env vars to push to ECR. (No Docker Hub config needed.)

## Backstage template bits (to fully automate like GitHub)
In your template:
- Create the repo (publish:gitlab).
- Save CI vars on the project (once) so pipelines “just work”:
  - AWS_REGION, AWS_ACCOUNT_ID, (optional) PROJECT_PUSH_TOKEN if you use the project-token pattern.
- Optionally: add a prepare-ECR job exactly as above (the pipeline will create the ECR repo on first run).
- (If you go IRSA) No secrets to store—clean.