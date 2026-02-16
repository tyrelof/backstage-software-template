# Node.js API Template

Production-ready REST API template using Node.js and Express.js.

## Overview

This template provides a solid foundation for building scalable Node.js REST APIs with:
- **Express.js** - lightweight web framework
- **Node.js 20** - LTS with security hardening
- **Docker** - containerization with multi-stage builds
- **Kubernetes** - deployment ready with health checks
- **GitLab CI/CD** - automated testing, linting, and deployment

## Project Structure

```
.
├─ src/                      # application source code
│  ├─ server.js              # application entry point
│  ├─ app.js                 # express configuration
│  ├─ controllers/           # request handlers
│  ├─ routes/                # API routes
│  └─ middleware/            # custom middleware
├─ charts/                   # helm chart for kubernetes deployment
│  └─ <app-name>/
├─ ci/                       # gitlab ci/cd pipeline stages
├─ docs/                     # documentation (TechDocs)
├─ .gitlab-ci.yml           # main gitlab ci configuration
├─ Dockerfile               # production docker image
├─ Makefile                 # development commands
├─ docker-compose.yml       # local development environment
├─ package.json             # npm dependencies
└─ catalog-info.yaml        # backstage service catalog
```

## Getting Started

### Prerequisites

- **Node.js**: 20.x or later
- **npm**: 10.x or later
- **Docker**: 20.10+ (for containerized development)

### Quick Start

#### Option 1: Local Development

```bash
# Install dependencies
npm ci

# Run application
npm start

# API will be available at http://localhost:3000
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

# Run linting
make lint

# Run tests
make test

# Run security audit
make audit
```

## Development Workflows

### Running the App

```bash
# Local: using npm directly
npm start
npm run dev

# Docker: using Makefile
make start
make dev
```

### Code Quality

```bash
# Linting
make lint

# Security audit
make audit
make security

# Generate security SBOM
make sbom
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
- **Readiness**: `GET /health/ready` - Application is ready to serve requests

### Response Format

```json
{
  "status": "OK",
  "timestamp": "2024-02-12T10:30:00Z",
  "version": "1.0.0"
}
```

## Environment Variables

Create a `.env` file in the project root:

```bash
# Server
NODE_ENV=development
PORT=3000

# Logging
LOG_LEVEL=info
```

**Note**: `.env` files are ignored in version control for security. Use GitLab CI/CD secrets for production.

## Docker

### Build Image

```bash
docker build -t myapp:latest .
```

### Run Container

```bash
docker run -p 3000:3000 \
  -e NODE_ENV=production \
  -e PORT=3000 \
  myapp:latest
```

### Security Features

- **Multi-stage build**: Reduces image size and attack surface
- **Non-root user**: Runs as nodejs user (UID 1001)
- **Alpine Linux**: Minimal base image (~40MB)
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
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

## CI/CD Pipeline

The GitLab CI/CD pipeline includes:

1. **Lint** (ci/10-lint.yml)
   - ESLint for code quality
   - yamllint for YAML files
   - helm lint for Kubernetes charts

2. **Test** (ci/20-tests.yml)
   - Jest test suite

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
# Run ESLint
make lint

# Run npm audit
make audit

# Generate SBOM
make sbom

# Full security check
make security
```

### Container Security

- **Image scanning**: Trivy scans for HIGH/CRITICAL vulnerabilities
- **Base image**: Node.js 20-alpine (regularly updated)
- **Non-root**: Container runs as unprivileged user
- **Layer caching**: Minimal build context for reduced attack surface

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

- **express**: Web framework
- **helmet**: Security headers
- **morgan**: HTTP request logging
- **cors**: Cross-Origin Resource Sharing
- **dotenv**: Environment configuration

### Development

- **nodemon**: Auto-reload on file changes
- **eslint**: Code quality
- **jest**: Testing framework (optional)

## Troubleshooting

### Port Already in Use

```bash
# Change default port
PORT=3001 npm start
```

### Docker Build Fails

```bash
# Clear build cache
docker build --no-cache -t myapp:latest .
```

### Installation Issues

```bash
# Clear npm cache
npm cache clean --force

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm ci
```

## Documentation References

- [Helm Chart Documentation](../charts/)
- [GitLab CI/CD Configuration](../ci/)
- [API Documentation](./docs/index.md)
- [Deployment Guide](./docs/deployment.md)
- [Secrets Management](./docs/secrets.md)

## Contributing

1. Follow the style guide (ESLint enforced)
2. Ensure all tests pass: `npm run test`
3. Update documentation for API changes
4. Create merge requests to main branch

## Support

For questions or issues:
1. Check the [Documentation](./docs/)
2. Review [GitLab CI/CD logs](https://gitlab.example.com)
3. Contact: ${{ values.owner }} (${{ values.system }})

## License

This template is part of the Backstage Catalog.
