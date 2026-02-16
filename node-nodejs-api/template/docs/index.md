# ${{ values.app_name }}

Node.js + Express REST API template with Docker, Kubernetes/Helm, and GitLab CI/CD integration.

---

## ✨ Features

### Backend API
- ✅ **Express.js** - Fast, minimalist web framework
- ✅ **Node.js 18+** - Runtime with native async/await
- ✅ **ESLint** - Code quality checks
- ✅ **Middleware Stack** - CORS, Helmet, Morgan logging

### Extensibility
- ✅ **Controllers Pattern** - Organized business logic
- ✅ **Routes Structure** - Modular route definitions
- ✅ **Middleware System** - Request validation, auth
- ✅ **Error Handling** - Consistent responses

### DevOps & Deployment
- ✅ **Kubernetes/Helm** - Container orchestration
- ✅ **Docker** - Multi-stage builds
- ✅ **GitLab CI/CD** - Automated pipelines
- ✅ **ArgoCD** - GitOps deployment
- ✅ **AWS Integration** - ECR, SSM, EKS

### Observability
- ✅ **Health Endpoints** - Liveness/Readiness probes
- ✅ **Structured Logging** - Morgan + JSON output
- ✅ **Request/Response Tracking** - Correlation IDs
- ✅ **TechDocs** - Comprehensive documentation

---

## 🚀 Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev
# or
make dev

# Server runs on http://localhost:3000
# Check health: curl http://localhost:3000/health
```

### Docker

```bash
# Build image
docker build -t my-api:latest .

# Run container
docker run -p 3000:3000 my-api:latest

# Health check
curl http://localhost:3000/health
```

### Kubernetes

```bash
# Install locally (requires Helm)
helm install my-api ./charts/my-api \
  --set serviceName=my-api \
  -f charts/my-api/values-stage.yaml

# Check status
kubectl get pods -l app=my-api
```

---

## 📂 Project Structure

```
.
├── src/                       # Application source
│   ├── server.js             # Entry point
│   ├── app.js                # Express app setup
│   ├── routes/               # Route handlers
│   │   ├── health.js         # Health endpoints
│   │   ├── users.js          # Users endpoints
│   │   └── api.js            # API router setup
│   ├── controllers/          # Business logic
│   │   └── userController.js
│   ├── middleware/           # Custom middleware
│   │   ├── auth.js           # Authentication
│   │   └── validation.js     # Request validation
│   └── utils/                # Helpers
├── charts/                   # Kubernetes Helm charts
│   └── my-api/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-stage.yaml
│       ├── values-prod.yaml
│       └── templates/        # K8s manifests
├── ci/                       # GitLab CI stage files
│   ├── 00-base.yml
│   ├── 10-lint.yml
│   ├── 20-test.yml
│   ├── 40-build.yml
│   └── 50-release.yml
├── docs/                     # TechDocs (this documentation)
├── Dockerfile                # Container definition
├── docker-compose.yml        # Local compose setup
├── .gitlab-ci.yml            # CI/CD entry point
├── .eslintrc.cjs             # ESLint configuration
├── package.json              # Dependencies
├── Makefile                  # development commands
└── README.md                 # Project README
```

---

## 🔧 Configuration

### Environment Variables

**Application (via ConfigMap)**:
```env
NODE_ENV=development
LOG_LEVEL=info
API_PORT=3000
```

**Sensitive (AWS SSM Parameter Store)**:
```
/${{ values.system }}/${{ values.app_name }}/stage/app
/${{ values.system }}/${{ values.app_name }}/prod/app
```

See [secrets.md](secrets.md) for detailed configuration management.

---

## 📦 Dependencies

### Key Packages
```json
{
  "express": "^4.18.2",
  "cors": "^2.8.5",
  "helmet": "^7.0.0",
  "morgan": "^1.10.0",
  "dotenv": "^16.3.1"
}
```

### Development

```bash
# Install dependencies
npm install

# Add new package
npm add <package-name>

# Add dev package
npm add --save-dev <package-name>

# Check for vulnerabilities
npm audit
npm audit fix
```

---

## 🐳 Container & Deployment

### Docker Build

```bash
# Multi-stage build (optimized for production)
docker build -t my-api:v1.0.0 .

# Build and run with compose
docker-compose up
```

### Running the Server

```bash
# Development (with auto-reload)
npm run dev

# Production
npm start
```

### Health Check

```bash
# Liveness probe
curl http://localhost:3000/health

# Readiness probe
curl http://localhost:3000/health/ready
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
2. **Test** - Unit tests (if configured)
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

## 🧪 Testing & Quality

```bash
# Run ESLint
npm run lint

# Fix linting issues automatically
npm run lint -- --fix
```

---

## 📊 Monitoring & Logs

```bash
# View server logs (development)
npm run dev

# View Kubernetes logs
kubectl logs deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage

# Stream logs
kubectl logs -f deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage

# Port-forward to service
kubectl port-forward svc/${{ values.app_name }} 3000:3000 -n ${{ values.app_name }}-stage

# Check health
curl http://localhost:3000/health
```

---

## 📚 Documentation

- [api.md](api.md) - API endpoints and routes
- [deployment.md](deployment.md) - Deployment procedures
- [kubernetes.md](kubernetes.md) - Helm and kubectl usage
- [gitlab-ci.md](gitlab-ci.md) - CI/CD pipeline
- [secrets.md](secrets.md) - Configuration and secrets
- [health-endpoints.md](health-endpoints.md) - Health probes

