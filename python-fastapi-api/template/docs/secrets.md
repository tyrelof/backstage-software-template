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
  LOG_LEVEL: "debug"
  # Add your own config:
  MY_API_URL: "https://api-staging.example.com"
```

### values-prod.yaml

```yaml
config:
  APP_ENV: "production"
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

### Database Connection Example (SQLAlchemy)

```python
# app/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
import os

DATABASE_URL = f"postgresql+asyncpg://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@{os.getenv('DB_HOST')}/{os.getenv('DB_NAME')}"

engine = create_async_engine(DATABASE_URL, echo=False, pool_pre_ping=True)

async def get_db() -> AsyncSession:
    async with SessionLocal() as session:
        yield session
```

### Secrets with Pydantic Settings

```python
# app/config.py
from pydantic_settings import BaseSettings
import os

class Settings(BaseSettings):
    # Database
    db_host: str = os.getenv("DB_HOST", "localhost")
    db_user: str = os.getenv("DB_USER", "")
    db_password: str = os.getenv("DB_PASSWORD", "")
    db_name: str = os.getenv("DB_NAME", "my_app")
    
    # Cache
    redis_url: str = os.getenv("REDIS_URL", "redis://localhost:6379")
    
    # Authentication
    jwt_secret: str = os.getenv("JWT_SECRET", "secret-key")
    
    # API Configuration (non-secret)
    api_url: str = os.getenv("MY_API_URL", "https://api.example.com")
    app_env: str = os.getenv("APP_ENV", "development")
    
    class Config:
        case_sensitive = False

settings = Settings()
```

### API Authentication Example

```python
# app/middleware/auth.py
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthCredentials
import jwt
from app.config import settings

security = HTTPBearer()

async def verify_token(credentials: HTTPAuthCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"]
        )
        return payload
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

### Redis Cache Example

```python
# app/cache.py
import redis.asyncio as redis
import json
from app.config import settings

redis_client = redis.from_url(settings.redis_url)

async def get_cache(key: str):
    value = await redis_client.get(key)
    return json.loads(value) if value else None

async def set_cache(key: str, value: dict, ttl: int = 3600):
    await redis_client.setex(key, ttl, json.dumps(value))
```

---

## 🔌 Environment Variables in FastAPI

All environment variables are **server-side only** in Python. There are no public/private distinctions like in Next.js.

```python
# ✅ All of these are server-side only (never exposed to client)
DB_HOST = "postgres.rds.amazonaws.com"
DB_PASSWORD = "secret-password"
JWT_SECRET = "secret-key"
REDIS_URL = "redis://redis:6379"
MY_API_URL = "https://api.example.com"
```

### Accessing in API Routes

```python
# app/routers/config.py
from fastapi import APIRouter
from app.config import settings

router = APIRouter()

@router.get("/api/config")
async def get_config():
    """Return non-sensitive config only"""
    return {
        # ✅ Can return non-secret settings
        "environment": settings.app_env,
        "api_url": settings.api_url,
        # ❌ NEVER return secrets
        # "jwt_secret": settings.jwt_secret,  # NEVER!
    }
```

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

- [ ] Database credentials are unique per environment (stage ≠ prod)
- [ ] Secrets are JSON formatted in AWS SSM
- [ ] External Secrets Operator is running on the platform
- [ ] Pod has `envFrom.secretRef` for secrets and `envFrom.configMapRef` for config
- [ ] Team has IAM access to SSM parameters they need
- [ ] CloudTrail is logging SSM parameter access
- [ ] Python environment uses asynchronous database drivers where applicable
- [ ] Pydantic Settings is used for centralized configuration management
- [ ] No secrets are logged or printed in application code
- [ ] All secrets use strong passwords (16+ characters, mixed case/numbers/symbols)

