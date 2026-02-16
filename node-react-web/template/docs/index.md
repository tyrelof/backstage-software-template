# ${{ values.app_name }}

React + Vite web application template with Nginx, Docker, Helm, and GitLab CI/CD integration.

---

## ✨ Features

### Frontend
- ✅ **React 18** - Modern UI library
- ✅ **Vite** - Fast dev server and optimized builds
- ✅ **ESLint** - Code quality checks
- ✅ **Nginx** - Production web server

### DevOps & Deployment
- ✅ **Kubernetes/Helm** - Container orchestration
- ✅ **Docker** - Multi-stage builds
- ✅ **GitLab CI/CD** - Automated pipelines
- ✅ **ArgoCD** - GitOps deployment
- ✅ **AWS Integration** - ECR, SSM, EKS

### Observability
- ✅ **Health Endpoint** - Liveness/Readiness probes
- ✅ **Nginx Logs** - Access/error logs
- ✅ **TechDocs** - Comprehensive documentation

---

## 🚀 Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Open browser
open http://localhost:5173
```

### Docker

```bash
# Build image
docker build -t my-web:latest .

# Run container
docker run -p 8080:80 my-web:latest

# Health check
curl http://localhost:8080/health
```

### Kubernetes

```bash
# Install locally (requires Helm)
helm install my-web ./charts/my-web \
  --set serviceName=my-web \
  -f charts/my-web/values-stage.yaml

# Check status
kubectl get pods -l app=my-web
```

---

## 📂 Project Structure

```
.
├── src/                    # React source code
│   ├── App.jsx            # Root component
│   ├── main.jsx           # Vite entry point
│   └── App.css            # Component styles
├── public/                # Static assets
├── charts/                # Kubernetes Helm charts
│   └── my-web/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-stage.yaml
│       ├── values-prod.yaml
│       └── templates/     # K8s manifests
├── ci/                    # GitLab CI stage files
│   ├── 00-base.yml
│   ├── 10-lint.yml
│   ├── 20-test.yml
│   ├── 40-build.yml
│   └── 50-release.yml
├── docs/                  # TechDocs (this documentation)
├── Dockerfile             # Container definition
├── docker-compose.yml     # Local compose setup
├── .gitlab-ci.yml         # CI/CD entry point
├── nginx.conf             # Nginx server config
├── eslint.config.cjs      # ESLint configuration
├── vite.config.js         # Vite configuration
├── package.json           # Dependencies
├── Makefile               # Local development commands
└── README.md              # Project README
```

---

## 🔧 Configuration

### Environment Variables

**Non-sensitive (ConfigMap)**:
```bash
# Helm values-stage.yaml
config:
  VITE_APP_ENV: "stage"
  VITE_API_URL: "https://api-staging.example.com"
```

**Sensitive (AWS SSM)**:
```bash
# AWS SSM Parameter Store
/${{ values.system }}/${{ values.app_name }}/stage/app
```

See [secrets.md](secrets.md) for detailed configuration management.

---

## 📦 Dependencies

### Key Packages
```json
{
  "react": "^18.2.0",
  "react-dom": "^18.2.0",
  "vite": "^4.x",
  "eslint": "^8.x",
  "@vitejs/plugin-react": "^4.x"
}
```

### Development

```bash
# Install dependencies
npm install

# Add new package
npm add <package-name>

# Update all packages
npm update

# Check for vulnerabilities
npm audit
npm audit fix
```

---

## 🐳 Container & Deployment

### Docker Build

```bash
# Multi-stage build (optimized for production)
docker build -t my-web:v1.0.0 .

# Build and run with compose
docker-compose up
```

### Kubernetes/Helm

```bash
# Install to staging
helm install ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }}-stage \
  --set serviceName=${{ values.app_name }} \
  -f charts/${{ values.app_name }}/values-stage.yaml

# Upgrade to new version
helm upgrade ${{ values.app_name }} ./charts/${{ values.app_name }} \
  -n ${{ values.app_name }}-stage \
  --set image.tag=v1.2.0

# View deployment
kubectl get deployment -n ${{ values.app_name }}-stage
```

See [deployment.md](deployment.md) for complete deployment patterns.

---

## 🔄 CI/CD Pipeline

**Automated on every push to `main`**:

1. **Lint** - ESLint, Helm lint, YAML validation
2. **Test** - Optional (if configured)
3. **Build** - Docker image build & push to ECR
4. **Release** - Auto-deploy to stage, manual approval for prod

```bash
# View pipeline
# GitLab: CI/CD > Pipelines

# Trigger manually
git push origin main
```

See [gitlab-ci.md](gitlab-ci.md) for pipeline details.

---

## 🧪 Testing

```bash
# Run lint
npm run lint

# Build production bundle
npm run build

# Preview build locally
npm run preview
```

---

## 📝 Code Quality

```bash
# Run ESLint
npm run lint

# Fix linting issues automatically
npm run lint -- --fix
```

---

## 🏥 Health Checks

```bash
# Nginx health endpoint
curl http://localhost/health
```

See [health-endpoints.md](health-endpoints.md) for probe configuration.

---

## 📊 Monitoring & Logs

```bash
# View nginx logs
kubectl logs deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage

# Stream logs
kubectl logs -f deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage

# Port-forward to service
kubectl port-forward svc/${{ values.app_name }} 8080:80 -n ${{ values.app_name }}-stage

# Check health
curl http://localhost:8080/health
```

---

## 📚 Documentation

- [api.md](api.md) - App routes and health endpoint
- [deployment.md](deployment.md) - Deployment procedures
- [kubernetes.md](kubernetes.md) - Helm and kubectl usage
- [gitlab-ci.md](gitlab-ci.md) - CI/CD pipeline
- [secrets.md](secrets.md) - Configuration and secrets
- [health-endpoints.md](health-endpoints.md) - Health probes

