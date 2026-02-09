# Kubernetes Deployment

The application is deployed to Amazon EKS using Kubernetes manifests and Helm charts.

## Kubernetes Resources

### Deployment
- **File**: `k8s/deployment.yaml`
- **Replicas**: 2 (production)
- **Strategy**: Rolling update
- **Health Checks**: Liveness and readiness probes

### Service
- **File**: `k8s/service.yaml`
- **Type**: ClusterIP
- **Port**: 80 (exposed), targets service port internally
- **Selector**: Routes traffic to deployment pods

### Ingress
- **File**: `k8s/ingress.yaml`
- **Controller**: nginx
- **TLS**: Enabled via cert-manager
- **Domains**: Production and staging

## Helm Deployment

### Chart Structure

```
charts/${{ values.app_name }}/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── serviceaccount.yaml
    ├── hpa.yaml
    └── _helpers.tpl
```

### Install Chart

```bash
# Staging environment
helm install ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }} \
  --create-namespace \
  -f values-staging.yaml

# Production environment
helm install ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }} \
  --create-namespace \
  -f values-prod.yaml
```

## Resource Requests and Limits

Configured in `charts/${{ values.app_name }}/values.yaml`:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

## Horizontal Pod Autoscaling

Automatically scales based on:
- **CPU**: 80% threshold
- **Memory**: 80% threshold
- **Min Replicas**: 2
- **Max Replicas**: 10

## Namespaces

Application runs in dedicated namespace: `${{ values.app_name }}`

```bash
# View resources in namespace
kubectl get all -n ${{ values.app_name }}

# View logs
kubectl logs -n ${{ values.app_name }} -l app=${{ values.app_name }}
```

## Network Policy

For security, consider implementing network policies:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${{ values.app_name }}
spec:
  podSelector:
    matchLabels:
      app: ${{ values.app_name }}
  policyTypes:
  - Ingress
  - Egress
```

## Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod <pod-name> -n ${{ values.app_name }}
kubectl logs <pod-name> -n ${{ values.app_name }}
```

### Ingress Not Working
```bash
kubectl describe ingress ${{ values.app_name }} -n ${{ values.app_name }}
```

### Check Service DNS
```bash
kubectl exec -it <pod-name> -n ${{ values.app_name }} -- nslookup kubernetes.default
```
