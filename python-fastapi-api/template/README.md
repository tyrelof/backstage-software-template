# README - FastAPI Template

This is a production-ready FastAPI template for Backstage software templates.

## Quick Start

### Local Development

```bash
# Install dependencies
make install

# Run application
make run

# Run tests
make test
```

### Docker

```bash
# Build and run
make docker-run

# Access at http://localhost:8000
```

### Kubernetes Deployment

```bash
# Deploy to staging
./scripts/deploy.sh ${{ values.app_name }} staging

# Deploy to production
./scripts/deploy.sh ${{ values.app_name }} production
```

## Template Structure

```
template/
├── src/                    # Application source code
│   ├── main.py            # FastAPI application entry point
│   ├── app/               # Application modules
│   │   ├── models.py      # Pydantic models
│   │   ├── logger.py      # Logging configuration
│   │   └── routers/       # API route handlers
│   └── tests/             # Unit tests
├── ci/                    # GitLab CI/CD pipeline stages
├── k8s/                   # Kubernetes manifests
├── charts/                # Helm charts
├── docs/                  # Documentation
├── scripts/               # Deployment and utility scripts
├── Dockerfile             # Container image definition
├── docker-compose.yml     # Local development compose file
├── Makefile              # Build automation
├── mkdocs.yaml           # Documentation configuration
└── requirements.txt      # Python dependencies
```

## Features

- ✅ FastAPI with automatic OpenAPI documentation
- ✅ Uvicorn ASGI server with hot reloading
- ✅ Health and readiness probes
- ✅ Comprehensive CI/CD pipeline (GitLab)
- ✅ Docker containerization with security best practices
- ✅ Kubernetes deployment manifests
- ✅ Helm charts with HPA support
- ✅ Automated testing with pytest
- ✅ Code quality tools (ruff, black, isort)
- ✅ MkDocs documentation
- ✅ Make build automation
- ✅ Docker Compose for local development

## Documentation

- [API Documentation](docs/api.md)
- [Health Endpoints](docs/health-endpoints.md)
- [GitLab CI/CD](docs/gitlab-ci.md)
- [Kubernetes Deployment](docs/kubernetes.md)
- [Deployment Guide](docs/deployment.md)

## Commands

### Development

```bash
make install          # Install dependencies
make dev              # Install dev dependencies
make test             # Run tests with coverage
make lint             # Run code quality checks
make format           # Auto-format code
make run              # Run locally with hot reload
make clean            # Remove build artifacts
```

### Docker

```bash
make build            # Build Docker image
make docker-run       # Run Docker container
make docker-clean     # Remove Docker images
```

## Testing

```bash
# Run all tests
pytest src/tests/ -v

# Run with coverage
pytest src/tests/ --cov=src --cov-report=html

# Run specific test file
pytest src/tests/test_api.py -v
```

## Code Quality

```bash
# Check code quality
ruff check src/

# Format code
black src/

# Sort imports
isort src/

# All at once
make format
```

## Kubernetes Commands

```bash
# View deployment status
kubectl get pods -n ${{ values.app_name }}

# Stream logs
kubectl logs -f -l app=${{ values.app_name }} -n ${{ values.app_name }}

# Check service
kubectl get svc -n ${{ values.app_name }}

# Check ingress
kubectl get ingress -n ${{ values.app_name }}
```

## Environment Variables

Application environment variables (set in values.yaml):

- `APP_ENV` - Environment (development, staging, production)
- `LOG_LEVEL` - Logging level (debug, info, warning, error)

## Support

For issues or questions, refer to:
- [Deployment Guide](docs/deployment.md)
- [Kubernetes Guide](docs/kubernetes.md)
- [GitLab CI Guide](docs/gitlab-ci.md)

## Owner

- **System**: ${{ values.system }}
- **Owner**: ${{ values.owner }}
