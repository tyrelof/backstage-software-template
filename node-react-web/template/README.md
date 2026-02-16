# React (Vite) Template

Modern React web application template using Vite for fast development and optimized builds.

## Layout

```
.
├─ src/                      # application source code
│  ├─ App.jsx                # root component
│  ├─ main.jsx               # vite entry point
│  └─ App.css
├─ public/                   # static assets
├─ charts/                   # helm chart(s) for kubernetes deployment
│  └─ <app-name>/
├─ ci/                       # gitlab ci/cd pipeline configs
├─ docs/                     # documentation (TechDocs)
├─ .gitlab-ci.yml
├─ Dockerfile               # multi-stage: build with node, serve with nginx
├─ Makefile                 # development commands (docker-powered)
├─ docker-compose.yml       # local development environment
├─ index.html               # vite static entry (required at root)
├─ vite.config.js
├─ package.json
└─ catalog-info.yaml
```

## Quick Start

### Prerequisites
- Node.js 20+
- npm 10+
- Docker (recommended for consistency)

### Local Development

```bash
# Install dependencies
npm ci

# Start dev server (http://localhost:5173)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Run linting
npm run lint
```

### Docker

```bash
# Using docker-compose
docker compose up

# Using make
make dev

# Using manual docker
docker build -t myapp:latest .
docker run -p 80:80 myapp:latest
```

## Technology Stack

- **React** 18.2 - UI library
- **Vite** 4.4 - build tool & dev server
- **Nginx** - production server
- **ESLint** - code quality
- **Docker** - containerization
- **Kubernetes** - orchestration (EKS)

## Development

### Available Scripts

```bash
make help         # Show all commands
make install      # Install dependencies
make dev          # Run dev server
make build        # Build for production
make preview      # Preview production build
make lint         # Run ESLint
make audit        # Check dependencies
make clean        # Remove build artifacts
make docker-build # Build Docker image
```

### Building

```bash
# Development build
npm run build

# Output: dist/ directory with optimized assets
```

## Deployment

### Docker Image

Multi-stage Dockerfile:
1. **Build stage**: Node.js 20 builds React app
2. **Production stage**: Nginx serves built assets

### Nginx Configuration

Health endpoint available at `GET /health`

### Kubernetes

Deploy using Helm chart:

```bash
helm install myapp ./charts/myapp \
  --namespace stage \
  --values values-stage.yaml
```

## Security

- ESLint for code quality
- Nginx security headers
- Node 20-alpine for minimal image
- Non-root user execution
- Trivy security scanning in CI/CD

## CI/CD Pipeline

- **Lint**: ESLint + yamllint + helm lint
- **Build**: Vite build + Docker image + Trivy scan
- **Release**: Stage (auto) / Production (manual)

## Troubleshooting

### Port conflict

```bash
npm run dev -- --port 5174
```

### Build errors

```bash
rm -rf node_modules package-lock.json
npm ci
npm run build
```

### Hot reload not working

Ensure volume mount in docker-compose or make command.

