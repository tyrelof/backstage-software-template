# ${{ values.app_name }}

FastAPI service template for ${{ values.app_name }}.

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run application
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Access API documentation
# http://localhost:8000/docs
```

### Docker

```bash
# Build image
docker build -t ${{ values.app_name }}:latest .

# Run container
docker run -p 8000:${{ values.service_port }} ${{ values.app_name }}:latest
```

### Health Checks

- **Liveness**: `GET /health` - Application is running
- **Readiness**: `GET /ready` - Application is ready to serve requests
- **Status**: `GET /api/v1/status` - Detailed status information

## Technology Stack

- **Framework**: FastAPI
- **ASGI Server**: Uvicorn
- **Python Version**: 3.11+
- **Container**: Docker
- **Orchestration**: Kubernetes (EKS)
- **Package Manager**: Helm
- **Testing**: pytest
- **Code Quality**: ruff, black, isort

## Documentation

- [API Documentation](api.md)
- [Health Endpoints](health-endpoints.md)
- [GitLab CI/CD](gitlab-ci.md)
- [Kubernetes Deployment](kubernetes.md)
- [Deployment Guide](deployment.md)

## Owner

- **System**: ${{ values.system }}
- **Owner**: ${{ values.owner }}
