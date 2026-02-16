# Backstage Software Templates

Opinionated, production-aligned Backstage Scaffolder templates for bootstrapping services on GitLab + Kubernetes (EKS).

This repository provides multi-language service templates with built-in CI/CD, containerization, Helm charts, and catalog registration to ensure a consistent production baseline across teams.

Each template includes project scaffolding plus common operational assets so new services can be created with standardized structure, delivery workflows, and deployment conventions.

---

## What this repository includes

- Multi-language templates for backend APIs and web applications
- Standardized template inputs for service identity, ownership, DNS, and AWS settings
- GitLab-first publishing workflow via `publish:gitlab`
- Automatic Backstage catalog registration via `catalog:register`
- Consistent repository structure across all stacks
- Minimal repository-level documentation under `docs/` (template maintenance only)

---

## Design principles

- Production-aligned defaults (CI pipelines, container best practices, security scanning)
- Explicit scaffolding over excessive abstraction
- Consistent repository layout across languages
- GitLab-based delivery workflows with EKS deployment targets
- Clear separation of platform responsibilities and application logic
- Templates reflect real-world operational patterns, not demo examples

---

## Available templates

### Go

- `go-base-service` — **Go Service (GitLab + EKS)**

### Python

- `python-fastapi-api` — **FastAPI REST API Service**
- `python-django-base` — **Django Service (GitLab + EKS)**

### Node.js / JavaScript

- `node-nodejs-api` — **Node.js REST API Service**
- `node-nextjs-web` — **Next.js Web Application**
- `node-react-web` — **React + Vite Web Application**

### PHP / Laravel

- `laravel-base-php7` — **Laravel Legacy Application (PHP 7.3)**
- `laravel-base-php8` — **Laravel Base Application (PHP 8.2)**
- `laravel-filament-php8` — **Laravel + Filament Admin Panel (PHP 8)**

---

## Repository structure

```text
.
├── catalog-info.yaml                  # Backstage Location for template targets
├── docs/                              # Repository-level documentation (template maintenance only)
├── entities/systems/                  # Backstage system entities
├── <template-name>/
│   ├── template.yaml                  # Scaffolder template definition
│   └── template/                      # Files copied into generated project
└── mkdocs_template.yaml               # Shared MkDocs scaffold fragment
