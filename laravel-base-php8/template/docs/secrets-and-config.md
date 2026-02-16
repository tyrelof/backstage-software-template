# Secrets and Configuration

This document explains **how application configuration and secrets work**
for services deployed on the platform.

It is written for **application developers**.

---

## 🔒 Source of Truth

**All secrets live in AWS SSM Parameter Store.**

Kubernetes secrets are **generated automatically** via:
- External Secrets Operator (ESO)
- Reloader (automatic pod restarts)

🚫 **Do NOT store secrets in:**
- Helm values
- Git
- `.env` files
- Backstage parameters

---

## 🧭 SSM Parameter Convention (MANDATORY)

Each service uses **exactly one SSM parameter per environment**.

### Parameter path

```
/<system>/<service>/<env>/app
```

Examples:
```
/popapps/orders/stage/app
/popapps/orders/prod/app
/agentix/chat/prod/app
```

Where:
- `system` → product domain (popapps, agentix, etc.)
- `service` → service name (Backstage app name)
- `env` → stage | prod
- `app` → fixed suffix (do not change)

---

## 🧱 Pre-created SSM Parameters (IMPORTANT)

For every service scaffolded by the platform:

- The SSM parameters are **automatically created** during the first deploy
- Paths already exist for both environments:
  ```
  /<system>/<service>/stage/app
  /<system>/<service>/prod/app
  ```
- Initial value is an **empty JSON placeholder**:
  ```json
  {}
  ```

✅ Developers **do NOT need to create the parameter**  
✅ Developers **ONLY update the value** when adding secrets

If the parameter already exists:
- Use **Edit** in the AWS Console, or
- Use `aws ssm put-parameter --overwrite`

---

## 📦 Parameter Format (IMPORTANT)

The **value MUST be valid JSON**.

Example:

```json
{
  "APP_KEY": "base64:xxxxxxxxxxxxxxxx",
  "DB_PASSWORD": "supersecret",
  "REDIS_PASSWORD": "anothersecret"
}
```

Rules:
- ✅ One JSON object only
- ✅ Flat key/value pairs
- ❌ No nested objects
- ❌ No YAML
- ❌ No plaintext files

If the JSON is invalid, the app **will not start**.

---

## 🛠 Creating or Updating a Parameter

### Option A: AWS Console (recommended)

1. Go to **AWS → SSM → Parameter Store**
2. Find the existing parameter:
   ```
   /<system>/<service>/<env>/app
   ```
3. Click **Edit**
4. Type:
   - `SecureString`
5. Value:
   - Paste the full JSON object
6. Save

ESO will pick it up automatically.

---

### Option B: AWS CLI

```bash
aws ssm put-parameter \
  --name "/popapps/orders/stage/app" \
  --type SecureString \
  --value '{
    "APP_KEY": "base64:xxxx",
    "DB_PASSWORD": "secret"
  }' \
  --overwrite \
  --region us-east-2
```

---

## 🔄 How Secrets Reach the Application

1. ESO reads the SSM parameter
2. ESO creates a Kubernetes Secret
3. Pods consume the secret via `envFrom`
4. **Reloader restarts pods automatically**

No Helm change required.  
No redeploy required.

---

## 🔁 Refresh Interval

Secrets are refreshed periodically.

Default:
```
every 5 minutes
```

This means:
- Secret changes propagate quickly
- AWS API usage stays safe

---

## 🔁 Do I Need to Restart the App?

### Usually: **NO**

Most secret changes trigger **automatic pod restarts** via Reloader.

### Manual restart (rare)

If a restart is needed:
- Use the **manual restart jobs** in GitLab CI

Production restarts require confirmation.

---

## 🧪 Bootstrap Secrets

Bootstrap secrets exist **only to allow the application to start**.

Typical use:
- Laravel `APP_KEY`

Rules:
- Automatically created by the platform
- **Temporary by design**
- ❌ Never store real secrets here
- ❌ Never rely on bootstrap in production
- ✅ **SSM secrets always override bootstrap values**

Once SSM contains values:
➡️ Bootstrap secrets become irrelevant

---

## ⚙️ Non-Secret Configuration

Non-secret configuration lives in Helm values:

```yaml
config:
  APP_ENV: "stage"
  LOG_LEVEL: "debug"
```

Rules:
- ✅ Safe, non-sensitive values only
- ❌ No passwords
- ❌ No tokens
- ❌ No credentials

---

## ❌ Common Mistakes (Avoid These)

- ❌ Creating multiple SSM parameters per service
- ❌ Storing secrets in Helm values
- ❌ Using non-JSON parameter values
- ❌ Forgetting the `/app` suffix
- ❌ Manually restarting pods unnecessarily

---

## ✅ Quick Checklist

Before asking for help, check:

- [ ] SSM path is correct
- [ ] JSON is valid
- [ ] Parameter is `SecureString`
- [ ] Correct AWS region
- [ ] Correct environment (stage vs prod)

---

## 🧠 Summary

- **SSM is the source of truth**
- **SSM parameters are pre-created by the platform**
- **Developers only update values**
- **ESO syncs automatically**
- **Reloader handles restarts**
- **Developers do not touch Kubernetes secrets**

If something looks wrong:
➡️ Check **SSM first**, then **ArgoCD**, then **pod logs**.

