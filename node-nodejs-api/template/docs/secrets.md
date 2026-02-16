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

## 🐳 Using Secrets in Application

### Database Connection Example

```javascript
// src/lib/db.js
const mysql = require('mysql2/promise');

async function getConnection() {
  return mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  });
}

module.exports = { getConnection };
```

### API Authentication Example

```javascript
// src/middleware/auth.js
const jwt = require('jsonwebtoken');

function verifyAuth(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'No token' });
  }
  
  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    req.user = verified;
    next();
  } catch (err) {
    res.status(403).json({ error: 'Invalid token' });
  }
}

module.exports = verifyAuth;
```

### Redis Cache Example

```javascript
// src/lib/cache.js
const redis = require('redis');

const client = redis.createClient({
  url: process.env.REDIS_URL,
  // TLS support for Redis URL with TLS
  ...(process.env.REDIS_TLS === 'true' && { tls: {} }),
});

async function getCache(key) {
  const value = await client.get(key);
  return value ? JSON.parse(value) : null;
}

async function setCache(key, value, ttl = 3600) {
  await client.setEx(key, ttl, JSON.stringify(value));
}

module.exports = { getCache, setCache };
```

---

## 🔌 Environment Variables in Node.js

### Server-Side Variables

All environment variables in Node.js/Express are **server-side only**. They're never sent to the client.

```javascript
// ✅ Available on server ONLY (accessing process.env)
DB_HOST = "postgres.rds.amazonaws.com"
DB_PASSWORD = "secret-password"
JWT_SECRET = "secret-key"
REDIS_URL = "redis://cache:6379"
API_KEY = "external-api-key"
```

**Usage in Express**:
```javascript
// src/app.js
const dbHost = process.env.DB_HOST;
const jwtSecret = process.env.JWT_SECRET;

// These are NEVER exposed to clients
```

---

## ⚠️ Important Notes

- **All server-side**: Node.js/Express doesn't have public environment variables (all are private/server-side)
- **All secrets are server-side**: Keep all sensitive data in environment variables or secrets management
- **Never log secrets**: Avoid logging API keys, database passwords, etc.
- **Runtime loading**: Node.js loads env vars at runtime (not build-time like Next.js/React)

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

- [ ] All secrets are kept server-side (never exposed in code)
- [ ] Database credentials are unique per environment (stage ≠ prod)
- [ ] Secrets are JSON formatted in AWS SSM
- [ ] External Secrets Operator is running on the platform
- [ ] Pod has `envFrom.secretRef` for secrets and `envFrom.configMapRef` for config
- [ ] Team has IAM access to SSM parameters they need
- [ ] CloudTrail is logging SSM parameter access

