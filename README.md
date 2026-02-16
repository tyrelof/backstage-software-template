# Backstage Software Templates

This repository contains a collection of reusable [Backstage Scaffolder](https://backstage.io/docs/features/software-templates/) templates for creating production-ready services and web applications.

Each template includes project scaffolding plus common operational assets (containerization, CI/CD, Kubernetes/Helm, and docs) so teams can bootstrap new services with a consistent baseline.

## What this repo includes

- Multi-language templates for backend APIs and web apps
- Standardized template inputs for service identity, ownership, DNS, and AWS settings
- Backstage catalog registration flow via `publish:gitlab` + `catalog:register`
- Minimal repository-level notes under `docs/`

## Available templates

### Go

- `go-base-service` — **Go Service (GitLab + EKS)**

### Python

- `python-fastapi-api` — **FastAPI REST API Service**
- `python-django-base` — **Django Service (GitLab + EKS)**

### Node.js / JavaScript

- `node-nodejs-api` — **Node.js REST API Service**
- `node-nextjs-web` — **Next.js Template**
- `node-react-web` — **React + Vite Web Application**

### PHP / Laravel

- `laravel-base-php7` — **Laravel Legacy Application (PHP 7.3)**
- `laravel-base-php8` — **Laravel Base Application (PHP 8.2)**
- `laravel-filament-php8` — **Laravel + Filament Admin Panel (PHP 8)**

## Repository structure

```text
.
├── catalog-info.yaml                  # Backstage Location for template targets
├── docs/                              # Repository-level documentation only
├── entities/systems/                  # Backstage system entities
├── <template-name>/
│   ├── template.yaml                  # Scaffolder template definition
│   └── template/                      # Files copied into generated project
└── mkdocs_template.yaml               # Shared MkDocs scaffold fragment
```

## Typical template flow

Most templates in this repo follow the same 3-step scaffolder flow:

1. `fetch:template` — render files from `template/` using user parameters
2. `publish:gitlab` — create repository and push generated code
3. `catalog:register` — register `catalog-info.yaml` in Backstage catalog

## Register templates in Backstage

1. Add template paths to `catalog-info.yaml` under `spec.targets`
2. In Backstage, register this repo/location (or refresh if already registered)
3. Open **Create** in Backstage and choose the desired template

Example target entry:

```yaml
spec:
  targets:
    - ./python-fastapi-api/template.yaml
    - ./node-nextjs-web/template.yaml
```

## Common required inputs

Most templates ask for a common set of parameters:

- `component_id` — canonical service name
- `ownerPath` — GitLab namespace/group
- `gitlabHost` — GitLab hostname
- `owner` / `system` — Backstage ownership and domain grouping
- `baseDomain` — primary DNS zone
- `servicePort` — container service port
- `awsAccountId` / `awsRegion` — ECR and deployment region settings

## Documentation

Top-level `docs/` is intentionally minimal and focused on template-repository maintenance.
Operational runbooks should live in platform repositories or in generated service repositories.

## Notes

- `catalog-info.yaml` currently controls which templates are discoverable in Backstage.
- You can keep inactive templates in this repo without exposing them by omitting them from `spec.targets`.
