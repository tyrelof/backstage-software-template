# Secrets and Configuration Management

This guide explains how secrets and configuration are managed in the FastAPI application.

## Overview

The application uses a three-tier approach to manage configuration and secrets:

1. **ConfigMap** - Non-secret, application configuration (environment variables)
2. **External Secrets Operator (ESO)** - Pulls secrets from AWS SSM Parameter Store
3. **Deployment** - Mounts both ConfigMap and secrets as environment variables

## Architecture

```
AWS SSM Parameter Store
  ↓
External Secrets Operator (ESO)
  ↓
Kubernetes Secret
  ↓
Pod environment variables
```

## Creating Secrets

### Step 1: Set up External Secrets Operator

External Secrets Operator must be installed in your cluster (usually by platform team):

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace
```

### Step 2: Create AWS SSM SecretStore

Create a `ClusterSecretStore` (platform setup, usually done once):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-ssm
spec:
  provider:
    aws:
      service: ParameterStore
      region: us-east-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-operator
```

### Step 3: Populate SSM Parameters

The CI/CD pipeline automatically creates placeholder parameters:

- `/${SYSTEM}/${APP_NAME}/stage/app` - Staging secrets
- `/${SYSTEM}/${APP_NAME}/prod/app` - Production secrets

Populate them via AWS CLI:

```bash
# Example: Set staging secrets
aws ssm put-parameter \
  --name "/popapps/myapp/stage/app" \
  --type "SecureString" \
  --value '{
    "DATABASE_URL": "postgresql://user:pass@db:5432/myapp_stage",
    "API_KEY": "sk-test-12345",
    "DEBUG": "false"
  }' \
  --overwrite

# Example: Set production secrets
aws ssm put-parameter \
  --name "/popapps/myapp/prod/app" \
  --type "SecureString" \
  --value '{
    "DATABASE_URL": "postgresql://user:pass@db-prod:5432/myapp",
    "API_KEY": "sk-prod-98765",
    "DEBUG": "false"
  }' \
  --overwrite
```

## Using Configuration

### ConfigMap (Non-Secret Configuration)

Define non-secret configuration in `values-*.yaml`:

```yaml
config:
  LOG_LEVEL: "info"
  MAX_WORKERS: "4"
  CACHE_TTL: "3600"
```

This creates a ConfigMap that's mounted as environment variables.

### Secrets from SSM

Secrets defined in SSM parameters are automatically:

1. Pulled by External Secrets Operator
2. Stored in Kubernetes Secret: `${APP_NAME}-secrets`
3. Injected as environment variables

The ESO `ExternalSecret` watches the SSM parameter and automatically:
- Refreshes every 5 minutes (configurable)
- Updates the Kubernetes secret when SSM changes
- Triggers pod restarts via Stakater Reloader

## Environment Variables

All configuration becomes environment variables in the pod:

```python
# FastAPI app can read them directly
import os

db_url = os.getenv("DATABASE_URL")
api_key = os.getenv("API_KEY")
log_level = os.getenv("LOG_LEVEL", "info")  # With default
```

### Priority Order

1. SSM secrets (highest priority - overwrites ConfigMap)
2. ConfigMap values
3. Pod default values

## Secrets Rotation

To rotate secrets:

1. Update SSM parameter:
```bash
aws ssm put-parameter \
  --name "/popapps/myapp/prod/app" \
  --type "SecureString" \
  --value '{"NEW_SECRET":"new_value"}' \
  --overwrite
```

2. ESO automatically updates Kubernetes secret (within 5 minutes)
3. Reloader automatically restarts pods with new secrets

## Troubleshooting

### Secrets not appearing

```bash
# Check if ESO is running
kubectl get pods -n external-secrets-system

# Check ExternalSecret status
kubectl describe externalsecret ${APP_NAME}-external

# Check if secret is created
kubectl get secret ${APP_NAME}-secrets -o yaml
```

### Pod not restarting after secret update

```bash
# Check Reloader annotations
kubectl describe pod ${POD_NAME} | grep "reloader.stakater.com"

# Manual pod restart
kubectl rollout restart deployment/${APP_NAME}
```

### SSM parameter not found

```bash
# List all SSM parameters
aws ssm describe-parameters --filters "Key=Name,Values=/popapps" --region us-east-2

# Check specific parameter
aws ssm get-parameter --name "/popapps/myapp/stage/app" --region us-east-2
```

## Security Best Practices

1. **Use SecureString** - SSM parameters created as SecureString (encrypted at rest)
2. **IAM Policy** - Limit ESO ServiceAccount to only read SSM parameters (not write/delete)
3. **RBAC** - Limit Kubernetes RBAC for secrets access
4. **Audit Logging** - Enable CloudTrail for SSM changes
5. **Secrets Rotation** - Regularly rotate API keys and passwords
6. **No Secrets in Git** - Never commit secrets to Git; use SSM only

## For Operators

### Enable/Disable External Secrets

In `values-*.yaml`:

```yaml
platform:
  secrets:
    external:
      enabled: true  # Set to false to disable ESO
      refreshInterval: 5m  # How often to sync from SSM
      deletionPolicy: Delete  # or Retain in production
```

### Custom Refresh Interval

```yaml
platform:
  secrets:
    external:
      refreshInterval: 30m  # Sync every 30 minutes (default 5m)
```

## Related Documentation

- [External Secrets Operator Docs](https://external-secrets.io/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
