# Next.js Template

Modern Next.js web application template with App Router and production-ready deployment configuration.

## Layout

```
.
├─ src/                      # application source code
│  └─ app/                   # next.js app router
│     ├─ page.js             # home page
│     ├─ layout.js           # root layout
│     └─ api/                # api routes
├─ public/                   # static assets
├─ charts/                   # helm chart(s) for kubernetes deployment
│  └─ <app-name>/
├─ ci/                       # gitlab ci/cd pipeline configs
├─ docs/                     # documentation (TechDocs)
├─ .gitlab-ci.yml
├─ Dockerfile               # multi-stage production build
├─ Makefile                 # development commands (docker-powered)
├─ docker-compose.yml       # local development environment
├─ next.config.js
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

# Start dev server (http://localhost:3000)
npm run dev

# Build for production
npm run build

# Start production server
npm start

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
docker run -p 3000:3000 myapp:latest
```

## Technology Stack

- **Next.js** 16.1+ - React framework with App Router
- **React** 18.2 - UI library
- **Node.js** 20 - runtime
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
make start        # Start production server
make lint         # Run ESLint
make test         # Run tests
make audit        # Check dependencies
make clean        # Remove build artifacts
make docker-build # Build Docker image
```

### Building

```bash
# Production-optimized build (standalone mode)
npm run build

# Output: .next/standalone directory
```

## Deployment

### Docker Image

Multi-stage Dockerfile:
1. **Deps stage**: Install dependencies
2. **Builder stage**: Build Next.js app (standalone output)
3. **Runner stage**: Minimal production image with built app

### Health Endpoints

Health check available at `GET /health`

### Kubernetes

Deploy using Helm chart:

```bash
helm install myapp ./charts/myapp \
  --namespace stage \
  --values values-stage.yaml
```

Health probes configured for liveness and readiness.

## Security

- ESLint for code quality
- Standalone Next.js build (smaller image)
- Node 20-alpine for minimal base
- Non-root user execution
- Trivy security scanning in CI/CD
- SBOM generation

## CI/CD Pipeline

- **Lint**: ESLint (flat config) + yamllint + helm lint
- **Test**: Jest test suite (optional)
- **Build**: Next.js build + Docker image + Trivy scan
- **Release**: Stage (auto) / Production (manual)

## API Routes

Next.js API routes in `src/app/api/`:

```js
// src/app/api/health/route.js
export async function GET() {
  return Response.json({ status: 'OK' });
}
```

## Troubleshooting

### Build errors

```bash
npm run build -- --verbose
```

### Port conflict

Update `PORT` environment variable or next.config.js.

### Cache issues

```bash
rm -rf .next node_modules package-lock.json
npm ci
npm run build
```

### Production mode debugging

```bash
npm run build
npm start -- --debug
```

