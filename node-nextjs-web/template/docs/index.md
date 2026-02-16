# ${{ values.app_name }}

Next.js 16 full-stack application template with built-in React components, API endpoints, Kubernetes deployment, and CI/CD pipeline.

---

## ✨ Features

### Frontend
- ✅ **Next.js 16** - Latest App Router
- ✅ **React 18** - Server & Client Components
- ✅ **TypeScript** - Full type safety
- ✅ **Tailwind CSS** - Styling
- ✅ **ESLint 9** - Modern linting

### Backend API
- ✅ **Route Handlers** - REST endpoints
- ✅ **Database Integration** - PostgreSQL/MySQL examples
- ✅ **Authentication** - JWT token verification
- ✅ **Validation** - Request/response schemas

### DevOps & Deployment
- ✅ **Kubernetes/Helm** - Container orchestration
- ✅ **Docker** - Multi-stage builds
- ✅ **GitLab CI/CD** - Automated pipelines
- ✅ **ArgoCD** - GitOps deployment
- ✅ **AWS Integration** - ECR, SSM, EKS

### Observability
- ✅ **Health Endpoints** - Liveness/Readiness probes
- ✅ **Structured Logging** - JSON logs
- ✅ **Metrics** - Prometheus-compatible
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

# Open browser
open http://localhost:3000
```

### Docker

```bash
# Build image
docker build -t my-app:latest .

# Run container
docker run -p 3000:3000 my-app:latest

# Build and run with compose
docker-compose up
```

### Kubernetes

```bash
# Install locally (requires Helm)
helm install my-app ./charts/my-app \
  --set serviceName=my-app \
  -f charts/my-app/values-stage.yaml

# Check status
kubectl get pods -l app=my-app
```

---

## 📂 Project Structure

```
.
├── src/                    # Frontend React components
│   ├── app/              # Next.js App Router
│   │   ├── api/          # Route handlers (API)
│   │   ├── page.tsx      # Home page
│   │   └── layout.tsx    # Root layout
│   ├── components/       # Reusable components
│   ├── lib/              # Utilities (auth, db, cache)
│   └── middleware.ts     # Request middleware
├── charts/               # Kubernetes Helm charts
│   └── my-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-stage.yaml
│       ├── values-prod.yaml
│       └── templates/    # K8s manifests
├── ci/                   # GitLab CI stage files
│   ├── 00-base.yml
│   ├── 10-lint.yml
│   ├── 20-test.yml
│   ├── 40-build.yml
│   └── 50-release.yml
├── docs/                 # TechDocs (this documentation)
├── Dockerfile            # Container definition
├── docker-compose.yml    # Local compose setup
├── .gitlab-ci.yml        # CI/CD entry point
├── eslint.config.cjs     # ESLint configuration
├── next.config.js        # Next.js configuration
├── package.json          # Dependencies
├── Makefile              # Local development commands
└── README.md             # Project README
```

---

## 🔧 Configuration

### Environment Variables

**Non-sensitive (ConfigMap)**:
```bash
# Helm values-stage.yaml
config:
  APP_ENV: "stage"
  NODE_ENV: "stage"
  LOG_LEVEL: "debug"
  NEXT_PUBLIC_API_URL: "https://api-staging.example.com"
```

**Sensitive (AWS SSM)**:
```bash
# AWS SSM Parameter Store
/${{ values.system }}/${{ values.app_name }}/stage/app
{
  "DATABASE_URL": "postgresql://...",
  "JWT_SECRET": "..."
}
```

See [secrets.md](secrets.md) for detailed configuration management.

---

## 📦 Dependencies

### Key Packages
```json
{
  "next": "^16.1.6",
  "react": "^18.2.0",
  "typescript": "^5.x",
  "eslint": "^9.0.0",
  "tailwindcss": "^3.x"
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
docker build -t my-app:v1.0.0 .

# Build for specific platform
docker buildx build --platform linux/amd64 -t my-app:latest .
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
2. **Test** - Unit tests (npm test)
3. **Build** - Docker image build & push to ECR
4. **Release** - Auto-deploy to stage, manual approval for prod

```bash
# View pipeline
# → GitLab: CI/CD > Pipelines

# Trigger manually
git push origin main

# Monitor build
# → Check logs in GitLab UI
```

See [gitlab-ci.md](gitlab-ci.md) for pipeline details and [deployment.md](deployment.md) for deployment procedures.

---

## 🧪 Testing

```bash
# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Generate coverage report
npm run test:coverage
```

---

## 📝 Code Quality

### Linting

```bash
# Run ESLint
npm run lint

# Fix linting issues automatically
npm run lint --fix
```

### Type Checking

```bash
# TypeScript type check
npx tsc --noEmit

# or as npm script
npm run type-check
```

### Formatting

```bash
# Format code
npm run format

# Check formatting
npm run format:check
```

---

## 🏥 Health Checks

**Liveness Probe** (is the app running?):
```bash
curl http://localhost:3000/health
# Response: 200 OK
```

**Readiness Probe** (can it handle traffic?):
```bash
curl http://localhost:3000/health/ready
# Response: 200 OK (when dependencies available)
```

See [health-endpoints.md](health-endpoints.md) for details.

---

## 🔐 Secrets & Configuration

**Non-sensitive config** (Helm values):
- Stored in `charts/${{ values.app_name }}/values-*.yaml`
- Applied as ConfigMap in Kubernetes
- Available as environment variables in pods

**Sensitive secrets** (AWS SSM):
- Stored in AWS Systems Manager Parameter Store
- Encrypted at rest
- Synced to pods by External Secrets Operator
- Updated automatically when changed

See [secrets.md](secrets.md) for management details.

---

## 📊 Monitoring & Observability

### Logs
```bash
# View application logs
kubectl logs deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage

# Stream logs
kubectl logs -f deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage

# View logs from pod
kubectl logs <pod-name> -n ${{ values.app_name }}-stage
```

### Metrics
- JSON structured logging
- Prometheus-compatible metrics (optional)
- CloudWatch integration via AWS container insights

### Debugging
```bash
# Port-forward to pod
kubectl port-forward svc/${{ values.app_name }} 3000:3000 -n ${{ values.app_name }}-stage

# Execute command in pod
kubectl exec <pod-name> -- curl http://localhost:3000/health -n ${{ values.app_name }}-stage

# View pod events
kubectl describe pod <pod-name> -n ${{ values.app_name }}-stage
```

See [kubernetes.md](kubernetes.md) for more debugging commands.

---

## 🔗 API Endpoints

See [api.md](api.md) for complete API documentation.

```bash
GET  /health                   # Liveness probe
GET  /health/ready             # Readiness probe
GET  /api/users                # List users
GET  /api/users/:id            # Get user
POST /api/users                # Create user (auth required)
```

---

## 📚 Documentation

- **[api.md](api.md)** - API endpoints, authentication, validation
- **[deployment.md](deployment.md)** - Deployment procedures, rollbacks
- **[kubernetes.md](kubernetes.md)** - Helm, kubectl commands, debugging
- **[gitlab-ci.md](gitlab-ci.md)** - CI/CD pipeline, stages, deployment
- **[secrets.md](secrets.md)** - Configuration management, AWS SSM
- **[health-endpoints.md](health-endpoints.md)** - Health checks, probes

---

## 🛠️ Makefile Commands

```bash
# Development
make dev          # Start development server
make build        # Build production bundle
make lint         # Run ESLint
make format       # Format code with Prettier
make test         # Run tests
make type-check   # TypeScript type checking

# Docker
make docker-build   # Build Docker image
make docker-run     # Run Docker container locally
make docker-push    # Push to ECR

# Kubernetes
make k8s-deploy     # Deploy to Kubernetes
make k8s-logs       # View pod logs
make k8s-shell      # Shell into pod
```

---

## 🤝 Contributing

1. Create branch: `git checkout -b feature/my-feature`
2. Make changes and commit: `git commit -am "Add feature"`
3. Push to branch: `git push origin feature/my-feature`
4. Open Merge Request in GitLab
5. Pipeline runs automatically
6. After approval, merge to `main`
7. Pipeline triggers deployment to stage

---

## 🚀 Deployment Checklist

Before deploying to production:

- [ ] All tests passing locally
- [ ] Code reviewed and approved
- [ ] Linting checks pass
- [ ] Staging deployment successful
- [ ] Health checks passing in stage
- [ ] No errors in logs
- [ ] Team member available for monitoring

See [deployment.md](deployment.md) for production deployment procedures.

---

## 📞 Support & Troubleshooting

### Common Issues

**Pod not starting?**
```bash
kubectl describe pod <pod-name> -n ${{ values.app_name }}-stage
kubectl logs <pod-name> -n ${{ values.app_name }}-stage
```

**Health checks failing?**
```bash
kubectl exec <pod-name> -n ${{ values.app_name }}-stage -- curl http://localhost:3000/health
```

**Database connection error?**
```bash
kubectl exec <pod-name> -n ${{ values.app_name }}-stage -- env | grep DATABASE_URL
```

See [kubernetes.md](kubernetes.md) for debugging guide.

---

## 📄 License

See LICENSE file in repository.

---

## 🔗 Quick Links

- **GitLab Repository**: [gitlab.example.com/platform/my-app](https://gitlab.example.com)
- **ArgoCD Dashboard**: [argocd.example.com](https://argocd.example.com)
- **Kubernetes Cluster**: EKS - us-east-2
- **Status Page**: [status.example.com](https://status.example.com)

