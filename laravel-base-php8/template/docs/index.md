# ${{ values.app_name }}

Welcome to ${{ values.app_name }}, a Laravel service (PHP 8) generated via Backstage.

This service follows the standard platform delivery model:
- CI builds container images
- CD deploys via ArgoCD (GitOps)
- Kubernetes runs the workload

For local development, this repository is **Makefile-driven**.

---

## 🚀 Overview

This service includes:

- Laravel 12 application scaffold (PHP 8.2)
- Optional queue workers (configurable)
- Nginx + PHP-FPM base image
- Kubernetes-ready Helm chart
- GitOps-based deployment via ArgoCD

---

## 🚢 Deployment Model (Important)

**You do not deploy this service manually.**

- CI builds images automatically
- ArgoCD deploys from Git
- Helm is managed by the platform

🚫 Do **not** run `helm upgrade` or deploy manually.

Deployment changes happen by:
- pushing code
- editing Helm values files (via Git)

---

## 📁 Kubernetes Manifests (`k8s/`)

This repository includes a `k8s/` directory containing **raw Kubernetes manifests**.

These files are provided **for reference and local use only**.

They may be useful for:
- learning basic Kubernetes resources
- testing on local clusters (kind / minikube / k3d)
- debugging rendered Helm output
- understanding how the service is structured at the Kubernetes level

⚠️ **Do NOT use the `k8s/` directory for production deployments.**

Production deployments are managed exclusively via:
- Helm charts (`charts/`)
- ArgoCD (GitOps)

If you are deploying to EKS or any shared environment, **always use the Helm chart**.

---

## ⚙️ Configuration (Helm values)

All runtime configuration lives in:

```
charts/${{ values.app_name }}/
```

Typical configuration includes:
- replicas / autoscaling
- CPU & memory resources
- ingress hosts & TLS
- workers & queues
- Reverb
- metrics scraping
- node selectors / tolerations

Changes are applied automatically via ArgoCD.

📄 See **`docs/secrets-and-config.md`** for secret management details.

This document explains:
- how secrets are delivered via AWS SSM + External Secrets Operator (ESO)
- the required SSM parameter path and JSON format
- how secret changes trigger pod restarts (Reloader)
- when a manual restart may be required

---

# 🔐 Accessing Private Databases (RDS)

All application databases run in **private subnets** and are **NOT publicly accessible**.

Developers access databases using **AWS SSM port forwarding** via a platform-provided helper script.

No VPN. No SSH. No public database endpoints.

---

### 🧰 SSM Tunnel Script

This repository includes a helper script:

```
scripts/ssm-tunnel.sh
```

The script establishes a **temporary local TCP tunnel** to a private RDS instance via the platform bastion.

---

### 🔐 Bastion (Platform-managed)

- **Instance ID:** `i-04017ff0b2ed2bafa`
- **Access:** AWS SSM only (no SSH, no public IP)
- **Stability:** Expected to remain stable unless explicitly re-created

---

### 🧑‍💻 How to Use the Tunnel Script

The recommended way is to use the helper script below.  
Advanced users may also run the raw `aws ssm start-session` command directly (see **Manual SSM Command** section).

#### 1️⃣ Make the script executable (first time only)

```bash
chmod +x scripts/ssm-tunnel.sh
```

---

#### 2️⃣ Start a tunnel

```bash
scripts/ssm-tunnel.sh <instance-id|instance-name> <rds-endpoint> [remotePort] [localPort]
```

- **instance-id / instance-name**  
  Platform bastion EC2 (usually `i-04017ff0b2ed2bafa`)
- **rds-endpoint**  
  RDS endpoint DNS name
- **remotePort** *(optional)*  
  Database port (default: `5432`)
- **localPort** *(optional)*  
  Local port on your machine (default: same as remote)

---

### Examples

**PostgreSQL**
```bash
scripts/ssm-tunnel.sh i-04017ff0b2ed2bafa mydb.xxx.us-east-2.rds.amazonaws.com 5432
```

**MariaDB / MySQL**
```bash
scripts/ssm-tunnel.sh i-04017ff0b2ed2bafa stage-shared-mariadb.xxx.us-east-2.rds.amazonaws.com 3306
```

**Custom local port**
```bash
scripts/ssm-tunnel.sh i-04017ff0b2ed2bafa mydb.xxx.us-east-2.rds.amazonaws.com 3306 13306
```

---

### 3️⃣ Connect Using Your DB Client

Use **localhost** in your DB tool:

| Setting | Value |
|------|------|
| Host | `127.0.0.1` |
| Port | `5432`, `3306`, etc |
| Username | from AWS SSM |
| Password | from AWS SSM |

Examples:

```bash
# PostgreSQL
psql -h 127.0.0.1 -p 5432 -U username dbname

# MySQL / MariaDB
mysql -h 127.0.0.1 -P 3306 -u username -p
```

---

### ⛔ Important Notes

- Keep the tunnel terminal **open** while using the database
- Press **Ctrl+C** to close the tunnel
- The tunnel is **temporary** and leaves no open ports behind
- Direct public database access is **not allowed**

---

### 🔧 Manual SSM Command (Advanced)

If you prefer not to use the helper script, you may start an SSM tunnel manually using the AWS CLI:

```bash
aws ssm start-session \
  --region us-east-2 \
  --target i-04017ff0b2ed2bafa \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<RDS_ENDPOINT>"],"portNumber":["5432"],"localPortNumber":["5432"]}'
```

Notes:
- Replace `<RDS_ENDPOINT>` with the actual RDS endpoint
- Adjust ports as needed (`3306`, `5432`, `1433`, etc.)
- Keep the terminal open while using your DB client
- This is functionally equivalent to `scripts/ssm-tunnel.sh`

---

### 🔍 Listing Available Databases

To list RDS instances:

```bash
aws rds describe-db-instances \
  --region us-east-2 \
  --query 'DBInstances[*].[DBInstanceIdentifier,Engine,Endpoint.Address,Endpoint.Port]' \
  --output table
```

Aurora clusters:

```bash
aws rds describe-db-clusters \
  --region us-east-2 \
  --query 'DBClusters[*].[DBClusterIdentifier,Engine,Endpoint,Port]' \
  --output table
```

---

## 🩺 Health & Observability

Standard platform endpoints:

| Endpoint | Purpose |
|--------|--------|
| `/healthz` | Liveness (NGINX-level, no PHP) |
| `/ready` | Readiness (cheap, file-based) |

Note:
- `/healthz` and `/ready` are provided by the platform and must remain fast.

📄 See **`docs/health-endpoints.md`** for details.

---

### 📊 Logs (Loki / Grafana)

Application logs are collected via **Loki** and queried through **Grafana**.

- Logs are labeled by Kubernetes namespace, pod, and container
- Always filter by namespace first
- Use regex for error and warning detection

📄 See **[LogQL / Loki Cheatsheet](logql-loki-cheatsheet.md)** for copy-paste queries and common filters.

---

## 🛠 Daily Developer Workflow

This repo uses a **Makefile-first workflow**.

⚠️ **Important (required before anything else)**

This service depends on **private GitLab Composer packages** hosted on `nexus.nmscreative.com`.

You **must** export your own GitLab **Personal Access Token (PAT)** before running *any* Make or Docker commands.

### 0️⃣ Prerequisite: Set Composer authentication

```bash
export COMPOSER_AUTH_JSON='{"gitlab-token":{"nexus.nmscreative.com":"glpat-xxxx-xxxx"}}'
```

Notes:
- Use **your own PAT**, not the shared CI/CD token
- Token must have read access to private repos (e.g. `nms/oauth`)
- This is required even for the initial Docker build
- You only need to do this once per terminal session

---

### 1️⃣ Start your local environment

```bash
make compose-run
```

Force rebuild (if base image or Dockerfile changed):

```bash
FORCE_BUILD=1 make compose-run
```

---

### 2️⃣ Install dependencies (Composer + frontend)

```bash
make vendor
make frontend-install
```

---

### 3️⃣ Run frontend dev server

```bash
make frontend-dev
```

---

### 4️⃣ Run Artisan commands

```bash
make artisan CMD="migrate"
make artisan CMD="config:clear"
make artisan CMD="queue:work"
```

---

### 5️⃣ Check logs

```bash
make compose-logs
```

---

### 6️⃣ Stop everything

```bash
make compose-down
```

---

## 🧰 Troubleshooting Cheatsheet

### ❌ `make compose-run` fails during build

- Ensure `COMPOSER_AUTH_JSON` is exported **before** running Make
- This is required even for the first local build

```bash
export COMPOSER_AUTH_JSON='{"gitlab-token":{"nexus.nmscreative.com":"glpat-xxxx-xxxx"}}'
make compose-run
```

---

### ❌ Composer install fails (private packages)

- Ensure `COMPOSER_AUTH_JSON` is set
- Token must be able to read private GitLab repos

```bash
make vendor
```

---

### ❌ Frontend not updating

```bash
make frontend-install
make frontend-dev
```

---

### ❌ App is running but not reachable

- Check `/healthz` and `/ready`
- Inspect ingress configuration in Helm values
- Check ArgoCD sync status

---

### ❌ Deployment looks wrong

- Open ArgoCD
- Verify:
  - image tag
  - values file
  - sync status
- Roll back by pinning a previous image tag

---

## 🧬 Backstage Catalog Metadata

This service is registered in Backstage via `catalog-info.yaml`.

### `lifecycle`

`lifecycle` describes the operational maturity of the service (not the deployment environment).

Recommended values:
- `development`
- `experimental`
- `production`
- `deprecated`

Update this in:
```yaml
spec.lifecycle
```

---

## 🧠 Expectations

- CI/CD is platform-owned
- Developers do not manage servers
- Rollbacks are Git-based (image tag pinning)
- If something breaks in an environment, check **ArgoCD first**

This setup is designed for scale, consistency, and low operational noise.

