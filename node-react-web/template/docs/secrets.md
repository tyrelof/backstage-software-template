# Secrets & Configuration Management

## Overview

This application uses **two mechanisms** for runtime configuration:

1. **ConfigMap** - Non-sensitive configuration in Helm `values-*.yaml` under `config:` section
2. **AWS SSM Parameter Store** - Sensitive secrets managed via External Secrets Operator (platform-level)

The External Secrets Operator is **configured at the platform level** and automatically syncs secrets from SSM to Kubernetes. Your app team doesn't need to set it up - just add values and the operator handles the rest!

---

## 🔐 Secrets Management Architecture

```
┌─────────────────────────────────────────┐
│   AWS SSM Parameter Store (encrypted)   │
│  /${SYSTEM}/${APP_NAME}/stage/app       │
│  /${SYSTEM}/${APP_NAME}/prod/app        │
└────────────────┬────────────────────────┘
                 │
    (Platform's External Secrets pulls)
                 │
                 ▼
┌─────────────────────────────────────────┐
│   Kubernetes Secret (in cluster)        │
│   my-app-external-secrets               │
└────────────────┬────────────────────────┘
                 │
         (Pod mounts as env vars)
                 │
                 ▼
┌─────────────────────────────────────────┐
│   Running Pod                           │
│   Accesses: process.env.DB_PASSWORD     │
└─────────────────────────────────────────┘
```

---

## 📝 Configuration (Non-Secret via Helm)

Non-sensitive configuration is stored in **Helm `values-*.yaml`** files under `config:`:

### values-stage.yaml

```yaml
config:
  APP_ENV: "stage"
  NODE_ENV: "stage"
  LOG_LEVEL: "debug"
  # Add your own config:
  MY_API_URL: "https://api-staging.example.com"
```

### values-prod.yaml

```yaml
config:
  APP_ENV: "production"
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  # Add your own config:
  MY_API_URL: "https://api.example.com"
```

### How It Works

The Helm chart creates a **ConfigMap** from the `config:` section:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-external-config
data:
  APP_ENV: "production"
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  MY_API_URL: "https://api.example.com"
```

Pod mounts both ConfigMap and Secrets:

```yaml
envFrom:
  - configMapRef:
      name: my-app-external-config  # Non-secret config
  - secretRef:
      name: my-app-external-secrets  # Secrets from SSM
```

---

## 🔑 Secrets (AWS SSM Parameter Store)

Sensitive data is stored in **AWS SSM Parameter Store**:

### SSM Parameter Paths

The CI/CD pipeline **automatically creates** these paths when you deploy:

```
/${{ values.system }}/${{ values.app_name }}/stage/app
/${{ values.system }}/${{ values.app_name }}/prod/app
```

**Example paths**:

```
/platform/my-app/stage/app
/platform/my-app/prod/app
```

### SSM Secret Format

Secrets are stored as **JSON objects** in SSM:

```json
{
  "DB_HOST": "postgres-stage.rds.amazonaws.com",
  "DB_USER": "app_user_stage",
  "DB_PASSWORD": "secret-password-123",
  "DB_NAME": "my_app_db",
  "REDIS_URL": "redis://redis-stage:6379",
  "JWT_SECRET": "super-secret-key-stage"
}
```

### Adding/Updating Secrets

Use **AWS CLI** to add or update SSM parameters:

```bash
# Add staging secrets
aws ssm put-parameter \
  --name "/platform/my-app/stage/app" \
  --type "SecureString" \
  --value '{
    "DB_HOST": "postgres-stage.rds.amazonaws.com",
    "DB_USER": "app_user",
    "DB_PASSWORD": "staging-password",
    "DB_NAME": "my_app_db"
  }' \
  --overwrite \
  --region us-east-2

# Add production secrets
aws ssm put-parameter \
  --name "/platform/my-app/prod/app" \
  --type "SecureString" \
  --value '{
    "DB_HOST": "postgres-prod.rds.amazonaws.com",
    "DB_USER": "app_user",
    "DB_PASSWORD": "production-password",
    "DB_NAME": "my_app_db_prod"
  }' \
  --overwrite \
  --region us-east-2
```

### Retrieving Secrets

```bash
# Get staging secrets
aws ssm get-parameter \
  --name "/platform/my-app/stage/app" \
  --with-decryption \
  --query 'Parameter.Value' \
  --region us-east-2 | jq .

# Output:
# {
#   "DB_HOST": "postgres-stage.rds.amazonaws.com",
#   "DB_PASSWORD": "***",
#   ...
# }
```

---

## 🔄 How External Secrets Works

The **platform-level External Secrets Operator** automatically:

1. Reads SSM parameters: `/${{ values.system }}/${{ values.app_name }}/{stage|prod}/app`
2. Converts JSON to individual key-value pairs
3. Creates Kubernetes Secret: `my-app-external-secrets`
4. Injects as environment variables into pods

**Your Helm chart** references the Secret (already done in the template):

```yaml
# In templates/deployment.yaml
envFrom:
  - configMapRef:
      name: {{ include "app.fullname" . }}-config
  - secretRef:
      name: {{ include "app.fullname" . }}-external  # Synced from SSM
```

---

## 🐳 Using Environment Variables in React

### Accessing Build-Time Variables

```javascript
// src/services/api.js
export const apiConfig = {
  baseUrl: import.meta.env.VITE_API_URL,
  env: import.meta.env.VITE_APP_ENV,
  analyticsId: import.meta.env.VITE_ANALYTICS_ID,
};

export async function fetchData(endpoint) {
  const response = await fetch(`${apiConfig.baseUrl}${endpoint}`);
  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }
  return response.json();
}
```

### Using in Components

```javascript
// src/components/Dashboard.jsx
import { useEffect, useState } from 'react';
import { fetchData, apiConfig } from '../services/api';

export function Dashboard() {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchData('/api/dashboard')
      .then(setData)
      .catch(setError);
  }, []);

  return (
    <div>
      <p>Environment: {apiConfig.env}</p>
      {error && <p>Error: {error.message}</p>}
      {data && <pre>{JSON.stringify(data, null, 2)}</pre>}
    </div>
  );
}
```

### Authentication with Backend

If your backend requires authentication tokens:

```javascript
// src/services/auth.js
const TOKEN_KEY = 'auth_token';

export function setToken(token) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export function fetchWithAuth(endpoint, options = {}) {
  const token = getToken();
  return fetch(`${import.meta.env.VITE_API_URL}${endpoint}`, {
    ...options,
    headers: {
      ...options.headers,
      'Authorization': `Bearer ${token}`,
    },
  });
}
```

---

## 🔌 Secrets in React (Vite)

### Environment Variables

React with Vite uses `VITE_` prefix for client-side environment variables. These are embedded at **build time** (not runtime):

```env
# .env.development
VITE_APP_ENV=development
VITE_API_URL=http://localhost:3000
VITE_ANALYTICS_ID=dev-ua-123456

# .env.production
VITE_APP_ENV=production
VITE_API_URL=https://api.example.com
VITE_ANALYTICS_ID=prod-ua-123456
```

### Accessing in Components

All `VITE_` variables are **client-side only** (available in browser):

```javascript
// src/App.jsx
import { useEffect, useState } from 'react';

export function App() {
  const apiUrl = import.meta.env.VITE_API_URL;
  const appEnv = import.meta.env.VITE_APP_ENV;

  useEffect(() => {
    // ✅ Can use VITE_ variables in browser
    fetch(`${apiUrl}/api/data`)
      .then(res => res.json())
      .then(data => console.log(data));
  }, [apiUrl]);

  return (
    <div>
      <p>Environment: {appEnv}</p>
      <p>API: {apiUrl}</p>
    </div>
  );
}
```

### Kubernetes ConfigMap

For different environments, use Helm values to set build-time variables:

```yaml
# charts/my-web/values-stage.yaml
config:
  VITE_APP_ENV: "stage"
  VITE_API_URL: "https://api-staging.example.com"
  VITE_ANALYTICS_ID: "stage-ua-123456"

# charts/my-web/values-prod.yaml
config:
  VITE_APP_ENV: "production"
  VITE_API_URL: "https://api.example.com"
  VITE_ANALYTICS_ID: "prod-ua-123456"
```

These are passed to the build process via Docker build args.

---

## 🔄 Secret Rotation

The External Secrets Operator automatically syncs AWS SSM changes to Kubernetes Secrets:

```bash
# 1. Update secret in AWS SSM
aws ssm put-parameter \
  --name "/platform/my-app/stage/app" \
  --type "SecureString" \
  --value '{
    "DB_PASSWORD": "new-password-xyz"
  }' \
  --overwrite \
  --region us-east-2

# 2. External Secrets updates the Kubernetes Secret (automatically)
# Typically within 1-5 minutes depending on RefreshInterval in values

# 3. Pods with replicaCount > 1 can be rolled gradually:
kubectl -n ${{ values.app_name }}-stage rollout restart deployment/${{ values.app_name }}

# 4. Verify new secrets are in use
kubectl -n ${{ values.app_name }}-stage logs -f deployment/${{ values.app_name }}
```

### Refresh Interval (Helm Values)

```yaml
# values-stage.yaml
# How often External Secrets checks for updates
refreshInterval: 5m    # Check every 5 minutes

# values-prod.yaml
refreshInterval: 1h    # Check every hour (less frequent)
```

---

## 🚨 Troubleshooting

### Secret Not Available in Pod

```bash
# 1. Check if SSM parameter exists
aws ssm get-parameter \
  --name "/platform/my-app/stage/app" \
  --region us-east-2 \
  --with-decryption

# 2. Check if Kubernetes Secret was created
kubectl -n ${{ values.app_name }}-stage get secrets
# Expected output includes: my-app-external-secrets

# 3. Verify Secret contents
kubectl -n ${{ values.app_name }}-stage get secret my-app-external-secrets -o yaml

# 4. Check External Secrets Controller logs
kubectl -n external-secrets logs -f deployment/external-secrets
```

### Pod Not Reading Secrets

```bash
# 1. Check pod environment variables
kubectl -n ${{ values.app_name }}-stage exec -it <pod-name> -- env | grep DB_

# 2. Check if secretRef is in deployment
kubectl -n ${{ values.app_name }}-stage get deployment my-app -o yaml | grep -A 10 secretRef

# 3. Restart pod to pick up new secrets
kubectl -n ${{ values.app_name }}-stage rollout restart deployment/my-app
```

### SSM Parameter Malformed

```bash
# Secrets must be valid JSON
aws ssm put-parameter \
  --name "/platform/my-app/stage/app" \
  --type "SecureString" \
  --value '{"DB_HOST":"postgres","DB_PASSWORD":"secret"}' \
  --overwrite

# ✅ Valid JSON with escaped quotes
aws ssm put-parameter \
  --name "/platform/my-app/stage/app" \
  --type "SecureString" \
  --value '{"user": "app", "pass": "123"}' \
  --overwrite

# ❌ Invalid - unescaped quotes will fail
aws ssm put-parameter \
  --name "/platform/my-app/stage/app" \
  --type "SecureString" \
  --value '{user: app, pass: 123}' \
  --overwrite
```

---

## 📋 Security Best Practices

### Do

✅ **Rotate secrets regularly** - Update AWS SSM parameters monthly  
✅ **Use strong passwords** - At least 16 characters with mixed case/numbers/symbols  
✅ **Limit IAM access** - Only give teams SSM access they need  
✅ **Audit secret access** - Enable CloudTrail for SSM parameter access  
✅ **Use SecureString type** - Always use encrypted parameters in SSM  

### Don't

❌ **Commit secrets** - Never add DB_PASSWORD to git or docker images  
❌ **Log secrets** - Filter sensitive vars from application logs  
❌ **Share secrets via email** - Use AWS Secrets Manager + IAM instead  
❌ **Use simple passwords** - Avoid "password123" or dictionary words  
❌ **Reuse secrets across environments** - Different secrets for stage/prod  

---

## 📚 Reference

| Method | Use Case | Managed By |
|--------|----------|-----------|
| ConfigMap (`config:` in Helm) | Non-sensitive config | Your Helm values |
| AWS SSM Parameter Store | Sensitive secrets | Platform team (External Secrets syncs) |
| Kubernetes Secret | Synced from SSM | External Secrets Operator |
| Environment Variables | App access | Pod spec `envFrom` |

---

## 🎯 Quick Checklist

- [ ] All `VITE_*` variables are set in Helm values for each environment
- [ ] Sensitive backend secrets use AWS SSM (if calling external APIs)
- [ ] Environment variables match between `.env.development`, `.env.production`, and Helm values
- [ ] Secrets are JSON formatted in AWS SSM
- [ ] External Secrets Operator is running on the platform (platform-provisioned)
- [ ] Pod has `envFrom.configMapRef` for public config
- [ ] Pod has `envFrom.secretRef` for backend secrets (if needed)
- [ ] Team has IAM access to SSM parameters they need
- [ ] Build environment variables don't leak sensitive data (VITE_* are client-visible)

