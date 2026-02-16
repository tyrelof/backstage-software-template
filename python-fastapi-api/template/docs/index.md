# ${{ values.app_name }}

Python FastAPI REST API template with Docker, Kubernetes/Helm, and GitLab CI/CD integration.

---

## ✨ Features

### Backend API
- ✅ **FastAPI** - Modern async Python web framework
- ✅ **Python 3.10+** - Latest language features
- ✅ **Pydantic** - Data validation and serialization
- ✅ **Uvicorn** - ASGI application server
- ✅ **Ruff** - Fast Python linter

### Extensibility
- ✅ **APIRouter** - Modular route definitions
- ✅ **Dependency Injection** - Built-in DI system
- ✅ **Middleware System** - Request/response processing
- ✅ **Error Handling** - Consistent exception handling

### DevOps & Deployment
- ✅ **Kubernetes/Helm** - Container orchestration
- ✅ **Docker** - Multi-stage builds
- ✅ **GitLab CI/CD** - Automated pipelines
- ✅ **ArgoCD** - GitOps deployment
- ✅ **AWS Integration** - ECR, SSM, EKS

### Observability
- ✅ **Health Endpoints** - Liveness/Readiness probes
- ✅ **Structured Logging** - Python logging with JSON output
- ✅ **Metrics** - Prometheus-compatible (optional)
- ✅ **TechDocs** - Comprehensive documentation

---

## 🚀 Quick Start

### Local Development

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start development server
python -m uvicorn app.main:app --reload
# or
make dev

# Server runs on http://localhost:8000
# API docs: http://localhost:8000/docs
# Check health: curl http://localhost:8000/health
```

### Docker

```bash
# Build image
docker build -t my-api:latest .

# Run container
docker run -p 8000:8000 my-api:latest

# Health check
curl http://localhost:8000/health
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
├── app/                       # Application source
│   ├── main.py               # FastAPI app entry point
│   ├── logger.py             # Logging configuration
│   ├── models.py             # Pydantic models
│   └── routers/              # Route modules
│       ├── health.py         # Health endpoints
│       ├── status.py         # Status endpoints
│       └── users.py          # Users endpoints (example)
├── tests/                    # Test suite
│   ├── test_main.py         # Main tests
│   └── test_routers.py      # Router tests
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
├── requirements.txt          # Python dependencies
├── Makefile                  # Development commands
└── README.md                 # Project README
```

---

## 🔧 Configuration

### Environment Variables

**Application (via ConfigMap)**:
```env
APP_ENV=development
LOG_LEVEL=INFO
API_PORT=8000
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
```text
fastapi==0.120.0           # Web framework
uvicorn[standard]==0.35.0  # ASGI server
pydantic==2.5.0            # Data validation
pydantic-settings==2.1.0   # Settings management
python-dotenv==1.0.0       # Environment variables
requests==2.32.4           # HTTP client
pytest==7.4.3              # Testing framework
```

### Development

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Add new package
pip install <package-name>

# Update requirements
pip freeze > requirements.txt

# Check for security issues
pip install safety
safety check
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
python -m uvicorn app.main:app --reload

# Production
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Health Check

```bash
# Liveness probe
curl http://localhost:8000/health

# Readiness probe
curl http://localhost:8000/health/ready

# API documentation
curl http://localhost:8000/docs
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

1. **Lint** - Ruff, Black, Isort, YAML validation
2. **Test** - Pytest with coverage
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
# Run tests
pytest

# Run tests with coverage
pytest --cov=app

# Run specific test
pytest tests/test_users.py::test_get_user

# Run linter (Ruff)
ruff check .

# Format code (Black)
black app/

# Sort imports (Isort)
isort app/

# Run all checks locally
make lint
make test
```

---

## 📊 Monitoring & Logs

```bash
# View server logs (development)
python -m uvicorn app.main:app --reload

# View Kubernetes logs
kubectl logs deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage

# Stream logs
kubectl logs -f deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage

# Port-forward to service
kubectl port-forward svc/${{ values.app_name }} 8000:8000 -n ${{ values.app_name }}-stage

# Check health
curl http://localhost:8000/health
```

---

## 📚 Documentation

- [api.md](api.md) - API endpoints and routes
- [deployment.md](deployment.md) - Deployment procedures
- [kubernetes.md](kubernetes.md) - Helm and kubectl usage
- [gitlab-ci.md](gitlab-ci.md) - CI/CD pipeline
- [secrets.md](secrets.md) - Configuration and secrets
- [health-endpoints.md](health-endpoints.md) - Health probes

