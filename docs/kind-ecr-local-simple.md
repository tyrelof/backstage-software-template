# Make CI/CD Work Locally (kind pulling from ECR)

**Goal:** Let your local **kind** cluster pull images from **ECR** (so your CI/CD works) **without changing any manifests**.

## Prereqs

- `kubectl` and `awscli` installed  
- Local AWS creds with ECR access (e.g., `AWS_PROFILE=admin`)  
- Your CI is already pushing images to ECR

---

## 0) Set vars (edit the first 3)

```bash
export AWS_PROFILE=admin
export AWS_REGION=ap-southeast-1
export NS=apps-dev   # namespace where your app deploys
```

---

## 1) Create/refresh ECR pull secret in your namespace

```bash
export AWS_ACCOUNT_ID=$(AWS_PROFILE=$AWS_PROFILE aws sts get-caller-identity --query Account --output text)
export REG="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

AWS_PROFILE=$AWS_PROFILE aws ecr get-login-password --region "$AWS_REGION" | kubectl create secret docker-registry ecr-pull   --namespace "$NS"   --docker-server="https://${REG}"   --docker-username="AWS"   --docker-password-stdin   --docker-email="none@none"   --dry-run=client -o yaml | kubectl apply -f -
```

_ECR token expires in ~12 hours. Re-run this step if pulls fail._

---

## 2) Make pods in that namespace use the secret (no manifest edits)

```bash
kubectl patch serviceaccount default -n "$NS"   -p '{"imagePullSecrets":[{"name":"ecr-pull"}]}'
```

**That’s it.** Now deploy the same way your CD already does (no changes needed) and the pods will be able to pull from ECR in your local cluster.

---

## Revert (optional, to clean up local wiring)

```bash
kubectl -n "$NS" patch serviceaccount default -p '{"imagePullSecrets":null}'
kubectl -n "$NS" delete secret ecr-pull --ignore-not-found
```

---

## Quick check

```bash
kubectl -n "$NS" get sa default -o yaml | grep -A2 imagePullSecrets
```

**Done.** Your CI/CD flow can run locally; kind will pull from ECR just like your remote does.
