# FastAPI Template

Production-ready REST API template using FastAPI and async Python.

## Overview

This template provides a solid foundation for building scalable Python REST APIs with:
- **FastAPI** - modern, fast web framework
- **Python 3.11** - latest stable with async/await support
- **Docker** - containerization with multi-stage builds
- **Kubernetes** - deployment ready with health checks
- **GitLab CI/CD** - automated testing, linting, and deployment

## Project Structure

```
.
├─ app/                      # application source code
│  ├─ main.py                # FastAPI application entry point
│  ├─ models.py              # Pydantic models
│  ├─ logger.py              # logging configuration
│  └─ routers/               # API route handlers
├─ tests/                    # unit tests
├─ charts/                   # helm chart for kubernetes deployment
│  └─ <app-name>/
├─ ci/                       # gitlab ci/cd pipeline stages
├─ docs/                     # documentation (TechDocs)
├─ scripts/                  # deployment and utility scripts
├─ .gitlab-ci.yml           # main gitlab ci configuration
├─ Dockerfile               # production docker image
├─ Makefile                 # development commands
├─ docker-compose.yml       # local development environment
├─ requirements.txt         # python dependencies
└─ catalog-info.yaml        # backstage service catalog
```

## Getting Started

### Prerequisites

- **Python**: 3.11+
- **pip**: 23+
- **Docker**: 20.10+ (for containerized development)

### Quick Start

#### Option 1: Local Development

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows

# Install dependencies
pip install -r requirements.txt

# Run application
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# API documentation will be available at http://localhost:8000/docs
```

#### Option 2: Docker Compose

```bash
# Start development environment
docker compose up

# View logs
docker compose logs -f

# Stop services
docker compose down
```

#### Option 3: Makefile (Docker-powered)

```bash
# See all available commands
make help

# Install dependencies (Docker)
make install

# Run dev server
make dev

# Run tests
make test

# Run security audit
make audit
```

## Development Workflows

### Running the App

```bash
# Local: using uvicorn directly
uvicorn app.main:app --reload

# Docker: using Makefile
make dev
```

### Code Quality

```bash
# Linting with ruff
make lint

# Code formatting
make format

# Security audit
make audit
make security
```

### Testing

```bash
# Run all tests with coverage
make test

# Run specific test file
pytest tests/test_api.py -v

# Run with coverage report
pytest --cov=app --cov-report=html
```

### Building for Production

```bash
# Build Docker image
docker build -t myapp:latest .

# Or use Makefile
make docker-build
```

## API Endpoints

### Health Checks

The application exposes health endpoints for Kubernetes probes:

- **Liveness**: `GET /health` - Application is running
- **Readiness**: `GET /ready` - Application is ready to serve requests
- **Status**: `GET /api/v1/status` - Detailed status information

### Response Format

```json
{
  "status": "healthy",
  "timestamp": "2024-02-12T10:30:00Z",
  "version": "1.0.0"
}
```

## Environment Variables

Create a `.env` file in the project root:

```bash
# Server
ENVIRONMENT=development
LOG_LEVEL=info
DEBUG=false

# Security
API_KEY_HEADER=X-API-Key
```

**Note**: `.env` files are ignored in version control for security. Use GitLab CI/CD secrets for production.

## Docker

### Build Image

```bash
docker build -t myapp:latest .
```

### Run Container

```bash
docker run -p 8000:8000 \
  -e ENVIRONMENT=production \
  -e LOG_LEVEL=info \
  myapp:latest
```

### Security Features

- **Multi-stage build**: Reduces image size and attack surface
- **Non-root user**: Runs as appuser (UID 1000)
- **Alpine base**: Minimal base image for smaller footprint
- **Security scanning**: Trivy scan in CI/CD pipeline
- **SBOM**: Software Bill of Materials generated in CI/CD

## Kubernetes Deployment

The template includes a Helm chart for Kubernetes deployment:

```bash
# Install release to stage
helm upgrade --install myapp ./charts/myapp \
  --namespace stage \
  --values charts/myapp/values-stage.yaml

# Install release to production
helm upgrade --install myapp ./charts/myapp \
  --namespace production \
  --values charts/myapp/values-prod.yaml
```

### Health Probes

Configured in `charts/myapp/values-*.yaml`:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 5
```

## CI/CD Pipeline

The GitLab CI/CD pipeline includes:

1. **Lint** (ci/10-lint.yml)
   - ruff for code linting
   - black/isort for formatting
   - yamllint for YAML files
   - helm lint for Kubernetes charts

2. **Test** (ci/20-tests.yml)
   - pytest test suite with coverage

3. **Build** (ci/30-build.yml)
   - Docker BuildKit image build
   - Trivy security scan
   - SBOM generation

4. **Release** (ci/40-release.yml)
   - Stage: Auto-deploy on main branch
   - Production: Manual approval required

5. **Operations** (ci/50-ops.yml)
   - Manual restart buttons for stage/production

### Triggering Pipelines

Pipelines trigger on:
- Push to `main` branch
- Merge requests to any branch
- Manual pipeline runs (via GitLab UI)

Change detection ensures:
- Build only when code/config changes
- Chart-only updates skip image rebuilds
- Efficient resource usage

## Security

### Code Security

```bash
# Run ruff linter
make lint

# Run black/isort formatters
make format

# Run tests
make test

# Generate SBOM
make sbom

# Full security check
make security
```

### Container Security

- **Image scanning**: Trivy scans for HIGH/CRITICAL vulnerabilities
- **Base image**: python:3.11-slim (regularly updated)
- **Non-root**: Container runs as unprivileged user
- **Layer caching**: Minimal build context for reduced attack surface
- **Dependency management**: pip audit in CI/CD

### Network Security

Configure in Helm values:

```yaml
# NetworkPolicy for pod-to-pod communication
networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
```

## Dependencies

### Production

- **FastAPI**: Web framework
- **Uvicorn**: ASGI server
- **Pydantic**: Data validation
- **python-dotenv**: Environment configuration

### Development

- **pytest**: Testing framework
- **pytest-cov**: Coverage reporting
- **ruff**: Fast Python linter
- **black**: Code formatter
- **isort**: Import sorter

For complete list, see `requirements.txt`.

## Troubleshooting

### Port Already in Use

```bash
# Change default port
PORT=8001 uvicorn app.main:app --reload
```

### Docker Build Fails

```bash
# Clear build cache
docker build --no-cache -t myapp:latest .
```

### Installation Issues

```bash
# Clear pip cache
pip cache purge

# Reinstall dependencies
rm -rf venv
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Debugging

```bash
# Enable debug logging
LOG_LEVEL=debug uvicorn app.main:app --reload

# Run tests with verbose output
pytest -vv --tb=short
```

## Documentation References

- [Helm Chart Documentation](./charts/)
- [GitLab CI/CD Configuration](./ci/)
- [API Documentation](./docs/index.md)
- [Deployment Guide](./docs/deployment.md)
- [Secrets Management](./docs/secrets.md)

## Contributing

1. Follow the style guide (ESLint enforced)
2. Ensure all tests pass: `make test`
3. Run linting: `make lint`
4. Run formatting: `make format`
5. Update documentation for API changes
6. Create merge requests to main branch

## Support

For questions or issues:
1. Check the [Documentation](./docs/)
2. Review [GitLab CI/CD logs](https://gitlab.example.com)
3. Contact: ${{ values.owner }} (${{ values.system }})

## License

This template is part of the Backstage Catalog.
