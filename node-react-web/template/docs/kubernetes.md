# Kubernetes Deployment via Helm

## Overview

This application is deployed to **AWS EKS (Elastic Kubernetes Service)** using **Helm** charts and **ArgoCD** for GitOps-style deployments.

**Deployment is fully automated via CI/CD** - when you push to `main`, the GitLab pipeline builds your image and ArgoCD syncs it to Kubernetes. This document explains how the Kubernetes infrastructure works and provides reference commands for DevOps teams.

> **Developers**: You don't need to run these commands manually. Just `git push` and CI/CD handles deployment. See [deployment.md](deployment.md) for your workflow.
>
> **DevOps/Platform Teams**: Use the commands in this document for troubleshooting, manual interventions, or understanding the infrastructure.

---

## 📦 Helm Chart Structure

```
charts/${{ values.app_name }}/
├── Chart.yaml                 # Chart metadata (name, version)
├── values.yaml               # Default values
├── values-stage.yaml         # Staging overrides
├── values-prod.yaml          # Production overrides
├── templates/                # Kubernetes manifests
│   ├── deployment.yaml       # Pod deployment
│   ├── service.yaml          # Kubernetes Service
│   ├── ingress.yaml          # HTTP ingress routing
│   ├── hpa.yaml              # Horizontal Pod Autoscaling
│   ├── configmap.yaml        # Non-secret configuration
│   ├── externalsecret.yaml   # External Secrets Operator sync
│   └── networkpolicy.yaml    # (Optional) Traffic restrictions
```

---

## 🚀 Deployment Methods

> **Note**: Deployments are **automated via CI/CD pipeline** when you push to `main`. The methods below are shown for **reference and understanding** of how Kubernetes deployments work. These commands are typically used by **DevOps teams** or **authorized personnel** for troubleshooting, manual interventions, or emergency operations.
> 
> **For normal development**: Just push your code to `main` - the CI/CD handles everything automatically. See [deployment.md](deployment.md) for the standard workflow.

### Method 1: Helm CLI (Reference - DevOps/Troubleshooting)

```bash
# Install to staging
helm install ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }}-stage \
  --create-namespace \
  -f charts/${{ values.app_name }}/values-stage.yaml

# Upgrade to new version
helm upgrade ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }}-stage \
  -f charts/${{ values.app_name }}/values-stage.yaml

# Check install status
helm status ${{ values.app_name }} -n ${{ values.app_name }}-stage

# View rendered manifests (debugging)
helm template ${{ values.app_name }} \
  ./charts/${{ values.app_name }} \
  -f values-stage.yaml > /tmp/rendered.yaml

# Rollback to previous release
helm rollback ${{ values.app_name }} 1 -n ${{ values.app_name }}-stage
```

### Method 2: ArgoCD (Reference - How GitOps Works)

**The CI/CD pipeline automatically manages ArgoCD applications**. This section explains how ArgoCD is configured behind the scenes.

**Configuration in Git** (managed by CI/CD):

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${{ values.app_name }}-prod
spec:
  project: default
  source:
    repoURL: https://gitlab.example.com/platform/${{ values.app_name }}.git
    targetRevision: main
    path: charts/${{ values.app_name }}/
    helm:
      valueFiles:
      - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ${{ values.app_name }}-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**CLI commands** (for DevOps reference):
```bash
# Check sync status (CI/CD does this automatically)
argocd app get ${{ values.app_name }}-prod

# Manual full sync (normally triggered by CI/CD)
argocd app sync ${{ values.app_name }}-prod

# Rollback (use for emergency rollbacks)
argocd app rollback ${{ values.app_name }}-prod 1

# Force hard refresh (troubleshooting only)
argocd app sync ${{ values.app_name }}-prod --force
```

---

## 📝 Helm Values Configuration

### values.yaml (Base Defaults)

```yaml
# Required: Fill in your application details
serviceName: ""  # e.g., "my-app"
system: "platform"

image:
  repository: ""  # e.g., "123456789.dkr.ecr.us-east-1.amazonaws.com/my-app"
  pullPolicy: IfNotPresent
  tag: "latest"

port: 3000
livenessPath: /health
readinessPath: /health/ready

replicaCount: 1

# Configuration (non-sensitive)
config: {}

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### values-stage.yaml (Staging Overrides)

```yaml
config:
  APP_ENV: "stage"
  NODE_ENV: "stage"
  LOG_LEVEL: "debug"
  REFRESH_INTERVAL: 5m

replicaCount: 1  # Staging: 1 replica

resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### values-prod.yaml (Production Overrides)

```yaml
config:
  APP_ENV: "production"
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  REFRESH_INTERVAL: 1h

replicaCount: 3  # Production: Multiple replicas

resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"

# Persistent storage deletion policy
deletionPolicy: "Retain"  # Keep secrets on uninstall
```

---

## 🐳 Kubernetes Manifests

### Deployment

The deployment creates pods from the container image:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ values.app_name }}
  namespace: ${{ values.app_name }}-stage
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: ${{ values.app_name }}
  template:
    metadata:
      labels:
        app: ${{ values.app_name }}
        platform.io/app: ${{ values.app_name }}
        platform.io/env: stage
        platform.io/system: ${{ values.system }}
    spec:
      containers:
      - name: app
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.port }}
        envFrom:
          # Non-sensitive configuration from ConfigMap
          - configMapRef:
              name: ${{ values.app_name }}-config
          # Sensitive secrets from AWS SSM (via External Secrets)
          - secretRef:
              name: ${{ values.app_name }}-external-secrets
        livenessProbe:
          httpGet:
            path: {{ .Values.livenessPath }}
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: {{ .Values.readinessPath }}
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
        resources: {{ toYaml .Values.resources | nindent 10 }}
```

### Service

Exposes the deployment on port 3000:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ${{ values.app_name }}-service
  namespace: ${{ values.app_name }}-stage
spec:
  type: ClusterIP
  selector:
    app: ${{ values.app_name }}
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
```

### ConfigMap

Maps `config:` values from Helm to environment variables:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${{ values.app_name }}-config
  namespace: ${{ values.app_name }}-stage
data:
  {{- range $key, $value := .Values.config }}
  {{ $key }}: "{{ $value }}"
  {{- end }}
```

### External Secrets

Syncs AWS SSM parameters to Kubernetes Secret:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${{ values.app_name }}-external-secrets
  namespace: ${{ values.app_name }}-stage
spec:
  refreshInterval: {{ .Values.refreshInterval }}
  secretStoreRef:
    name: aws-ssm
    kind: ClusterSecretStore
  target:
    name: ${{ values.app_name }}-external-secrets
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: /${{ values.system }}/${{ values.app_name }}/stage/app
```

---

## 🔍 Debugging & Troubleshooting

### Check Deployment Status

```bash
# List all deployments in staging
kubectl -n ${{ values.app_name }}-stage get deployments

# View detailed deployment info
kubectl -n ${{ values.app_name }}-stage describe deployment ${{ values.app_name }}

# Check which pods are running
kubectl -n ${{ values.app_name }}-stage get pods
kubectl -n ${{ values.app_name }}-stage get pods -o wide

# View pod events (recent issues)
kubectl -n ${{ values.app_name }}-stage describe pod <pod-name>
```

### View Logs

```bash
# Live logs from pod
kubectl -n ${{ values.app_name }}-stage logs -f deployment/${{ values.app_name }}

# Last 100 lines
kubectl -n ${{ values.app_name }}-stage logs deployment/${{ values.app_name }} --tail=100

# All pods in deployment
kubectl -n ${{ values.app_name }}-stage logs -f deployment/${{ values.app_name }} --all-containers

# Previous container (if pod crashed)
kubectl -n ${{ values.app_name }}-stage logs <pod-name> --previous
```

### Check Environment Variables

```bash
# List all env vars in a pod
kubectl -n ${{ values.app_name }}-stage exec -it <pod-name> -- env

# Check specific var
kubectl -n ${{ values.app_name }}-stage exec <pod-name> -- printenv NODE_ENV

# Check config map content
kubectl -n ${{ values.app_name }}-stage get configmap ${{ values.app_name }}-config -o yaml

# Check secret content (base64 encoded)
kubectl -n ${{ values.app_name }}-stage get secret ${{ values.app_name }}-external-secrets -o yaml
```

### Port Forward (Local Testing)

```bash
# Forward pod port 3000 to localhost:3000
kubectl -n ${{ values.app_name }}-stage port-forward deployment/${{ values.app_name }} 3000:3000

# Test connection
curl http://localhost:3000/health

# Access from other machine (optional)
# kubectl -n my-app-stage port-forward --address 0.0.0.0 deployment/my-app 3000:3000
```

### Check External Secrets Sync

```bash
# View ExternalSecret status
kubectl -n ${{ values.app_name }}-stage describe externalsecret ${{ values.app_name }}-external-secrets

# Check if secrets synced successfully
kubectl -n ${{ values.app_name }}-stage get externalsecrets

# View External Secrets Operator logs (platform namespace)
kubectl -n external-secrets logs -f deployment/external-secrets
```

### Restart Pods

```bash
# Graceful restart (respects pod disruption budgets)
kubectl -n ${{ values.app_name }}-stage rollout restart deployment/${{ values.app_name }}

# Wait for completion
kubectl -n ${{ values.app_name }}-stage rollout status deployment/${{ values.app_name }}

# Force delete a problematic pod (creates new one)
kubectl -n ${{ values.app_name }}-stage delete pod <pod-name> --grace-period=0 --force
```

---

## 📊 Monitoring & Observability

### Resource Usage

```bash
# View current resource usage
kubectl -n ${{ values.app_name }}-stage top pods

# Track over time
kubectl -n ${{ values.app_name }}-stage top pods --containers

# Compare to limits
kubectl -n ${{ values.app_name }}-stage describe node
```

### Events

```bash
# Kubernetes events (useful for debugging failures)
kubectl -n ${{ values.app_name }}-stage get events --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl -n ${{ values.app_name }}-stage get events -w
```

### Scaling

```bash
# Manual scaling (emergency only - use HPA in prod)
kubectl -n ${{ values.app_name }}-stage scale deployment/${{ values.app_name }} --replicas=3

# View HPA status
kubectl -n ${{ values.app_name }}-stage get hpa
kubectl -n ${{ values.app_name }}-stage describe hpa ${{ values.app_name }}-hpa
```

---

## 🔄 Update Procedures

> **Note**: Updates happen automatically via CI/CD. These commands show how updates work behind the scenes and are useful for DevOps troubleshooting.
>
> **Normal workflow**: Edit `values-*.yaml` → commit → push → CI/CD updates automatically.

### Update via Helm Values Change (How CI/CD Does It)

```bash
# 1. Edit values file (in your repo, then commit)
nano charts/${{ values.app_name }}/values-stage.yaml

# 2. Validate changes (CI/CD does this in lint stage)
helm template ${{ values.app_name }} ./charts/${{ values.app_name }} -f values-stage.yaml > /tmp/test.yaml

# 3. Apply update (CI/CD does this via ArgoCD)
helm upgrade ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }}-stage \
  -f values-stage.yaml

# 4. Monitor rollout (ArgoCD does this automatically)
kubectl -n ${{ values.app_name }}-stage rollout status deployment/${{ values.app_name }}
```

### Update via Image Tag (Automated by CI/CD)

**CI/CD automatically updates the image tag** when you push code. Here's how it works:

```bash
# CI/CD runs: Update image tag via yq
yq -i '.image.tag = "abc123def456"' charts/${{ values.app_name }}/values-stage.yaml

# Then commits and pushes
git add charts/${{ values.app_name }}/values-stage.yaml
git commit -m "chore: bump image"
git push

# ArgoCD detects change and syncs automatically

# Verify new version (for troubleshooting)
kubectl -n ${{ values.app_name }}-stage get pods -o jsonpath='{.items[0].spec.containers[0].image}'
```

### Rollback (Emergency Use)

```bash
# View release history
helm history ${{ values.app_name }} -n ${{ values.app_name }}-stage

# Rollback to previous release
helm rollback ${{ values.app_name }} -n ${{ values.app_name }}-stage

# Rollback to specific release number
helm rollback ${{ values.app_name }} 3 -n ${{ values.app_name }}-stage
```

---

## 🎯 Common Issues

### ImagePullBackOff Error

ECR image can't be pulled - verify:

```bash
# 1. Image exists in ECR
aws ecr describe-images --repository-name ${{ values.app_name }} --region us-east-2

# 2. Pod has correct IAM permissions
kubectl -n ${{ values.app_name }}-stage describe pod <pod-name> | grep -i "pull"

# 3. Image repository in values is correct
kubectl -n ${{ values.app_name }}-stage get deployment ${{ values.app_name }} -o yaml | grep image:
```

### CrashLoopBackOff Error

Pod keeps restarting - check logs:

```bash
# View application error
kubectl -n ${{ values.app_name }}-stage logs <pod-name> --previous

# Check dependencies (DB, Redis, etc)
kubectl -n ${{ values.app_name }}-stage exec <pod-name> -- curl http://db-host:5432

# Verify environment variables loaded
kubectl -n ${{ values.app_name }}-stage exec <pod-name> -- printenv
```

### Pods Pending

Pods not getting scheduled:

```bash
# Check resource availability
kubectl describe node | grep -A 5 "Allocated resources"

# View pending pod events
kubectl -n ${{ values.app_name }}-stage describe pod <pending-pod-name>

# Increase pod resource requests if needed
helm upgrade ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }}-stage \
  --set resources.requests.memory=256Mi
```

---

## 📚 Reference

| Command | Purpose |
|---------|---------|
| `helm install` | Initial deployment |
| `helm upgrade` | Update existing deployment |
| `helm rollback` | Revert to previous version |
| `helm template` | Preview rendered manifests |
| `kubectl apply -f` | Apply raw YAML manifests |
| `kubectl patch` | Quick inline edits |
| `kubectl logs` | View application output |
| `kubectl exec` | Run commands in pod |
| `kubectl port-forward` | Access pod locally |

