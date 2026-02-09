> ⚠️ **Status: OUTDATED / ARCHIVED**
>
> This document reflects an **older or superseded approach**.
> It is kept **for historical reference and context only**.
>
> **Do not use this document as a source of truth for new work.**
>
> A newer or replacement document is **not yet available**.
>
> Last verified: **unknown**

# Backstage Software Template — PHP (Laravel-ready)

This is a complete **Backstage Scaffolder** template for generating a production‑ready PHP service (plain PHP or Laravel), with optional Docker, Helm, TechDocs, and CI (GitHub Actions or GitLab CI). Drop the `template.yaml` into your Backstage catalog (or a `templates/` repo) alongside the `skeleton/` folder below.

---

## template.yaml (v1beta3)

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: php-service
  title: PHP Service (Laravel‑ready)
  description: Generate a PHP (Laravel or plain) service with Docker, Helm, TechDocs, and CI.
  tags: [php, laravel, helm, docker, techdocs, ci]
spec:
  owner: platform-team
  type: service

  parameters:
    - title: Service basics
      required: [name, system, owner, framework]
      properties:
        name:
          title: Service name
          type: string
          description: Kebab‑case name for the service/repo
          pattern: "^[a-z0-9-]+$"
        system:
          title: System
          type: string
          description: Backstage system this service belongs to
        owner:
          title: Owner (Backstage group or user)
          type: string
          description: e.g. group:devops or user:tyrel
        description:
          title: Description
          type: string
        framework:
          title: PHP framework
          type: string
          default: laravel
          enum: [laravel, symfony, plain]
        phpVersion:
          title: PHP version
          type: string
          default: "8.3"
          enum: ["8.3", "8.2"]

    - title: Repo & options
      required: [repoUrl]
      properties:
        repoUrl:
          title: Repository Location
          type: string
          ui:field: RepoUrlPicker
          ui:options:
            allowedHosts:
              - github.com
              - gitlab.com
        enableDocker:
          title: Include Dockerfile & docker-compose
          type: boolean
          default: true
        enableHelm:
          title: Include Helm chart
          type: boolean
          default: true
        enableTechDocs:
          title: Include TechDocs (MkDocs)
          type: boolean
          default: true
        ciProvider:
          title: CI provider
          type: string
          default: github
          enum: [github, gitlab]

  steps:
    - id: fetch-base
      name: Fetch skeleton
      action: fetch:template
      input:
        url: ./skeleton
        targetPath: ./
        values:
          name: ${{ parameters.name }}
          system: ${{ parameters.system }}
          owner: ${{ parameters.owner }}
          description: ${{ parameters.description }}
          framework: ${{ parameters.framework }}
          phpVersion: ${{ parameters.phpVersion }}
          enableDocker: ${{ parameters.enableDocker }}
          enableHelm: ${{ parameters.enableHelm }}
          enableTechDocs: ${{ parameters.enableTechDocs }}
          ciProvider: ${{ parameters.ciProvider }}

    - id: publish
      name: Publish to repository
      action: publish:github
      if: ${{ parameters.repoUrl | parseRepoUrl | isHost 'github.com' }}
      input:
        repoUrl: ${{ parameters.repoUrl }}
        defaultBranch: main
        repoVisibility: private

    - id: publish-gitlab
      name: Publish to GitLab
      action: publish:gitlab
      if: ${{ parameters.repoUrl | parseRepoUrl | isHost 'gitlab.com' }}
      input:
        repoUrl: ${{ parameters.repoUrl }}
        defaultBranch: main
        visibility: private

    - id: register
      name: Register in Backstage catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['publish']?.output.repoContentsUrl || steps['publish-gitlab']?.output.repoContentsUrl }}
        catalogInfoPath: "/catalog-info.yaml"

  output:
    links:
      - title: Repository
        url: ${{ steps['publish']?.output.remoteUrl || steps['publish-gitlab']?.output.remoteUrl }}
      - title: Open in Backstage
        icon: catalog
        entityRef: ${{ steps['register'].output.entityRef }}
```

> **Note:** The conditional `if:` in steps relies on scaffolder template filters (`parseRepoUrl`, `isHost`) available in modern Backstage versions. If your Backstage doesn’t support this yet, keep a single `publish:github` or switch both steps manually.

---

## `catalog-info.yaml` (generated)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.name }}
  description: ${{ values.description | default('PHP service') }}
  annotations:
    backstage.io/techdocs-ref: dir:.
    github.com/project-slug: ${{ values.repoSlug || '' }}
spec:
  type: service
  owner: ${{ values.owner }}
  system: ${{ values.system }}
  lifecycle: experimental
```

---

## Skeleton layout (templated)

```
skeleton/
├─ catalog-info.yaml
├─ README.md
├─ composer.json
├─ public/
│  └─ index.php
├─ src/
│  └─ App.php
├─ Dockerfile           # if enableDocker
├─ docker-compose.yml   # if enableDocker
├─ nginx/nginx.conf     # if enableDocker
├─ helm/                # if enableHelm
│  ├─ Chart.yaml
│  ├─ values.yaml
│  └─ templates/
│     ├─ deployment.yaml
│     ├─ service.yaml
│     └─ ingress.yaml
├─ .github/workflows/ci.yml   # if ciProvider == github
├─ .gitlab-ci.yml             # if ciProvider == gitlab
├─ mkdocs.yml            # if enableTechDocs
└─ docs/index.md         # if enableTechDocs
```

---

## `skeleton/README.md`

````md
# ${{ values.name }}

${{ values.description | default('A PHP service scaffolded by Backstage.') }}

## Quickstart

### Requirements
- PHP ${{ values.phpVersion }}
- Composer 2.x
- (Optional) Docker & Docker Compose

### Local
```bash
composer install
php -S 0.0.0.0:8080 -t public
````

Open [http://localhost:8080](http://localhost:8080)

### Docker

```bash
docker compose up --build
```

### Helm (example)

```bash
helm upgrade --install ${{ values.name }} ./helm -n default
```

````

---

## `skeleton/composer.json`

```json
{
  "name": "org/${{ values.name }}",
  "description": "${{ values.description | default('PHP service') }}",
  "type": "project",
  "require": {
    "php": ">=${{ values.phpVersion }}",
    {% if values.framework == 'laravel' %}
    "laravel/framework": "^11.0"
    {% elif values.framework == 'symfony' %}
    "symfony/http-foundation": "^7.0",
    "symfony/routing": "^7.0"
    {% else %}
    "nikic/fast-route": "^1.3"
    {% endif %}
  },
  "require-dev": {
    "phpunit/phpunit": "^11.0"
  },
  "autoload": {
    "psr-4": {
      "App\\": "src/"
    }
  },
  "scripts": {
    "start": "php -S 0.0.0.0:8080 -t public"
  }
}
````

---

## `skeleton/public/index.php`

```php
<?php
declare(strict_types=1);

// Minimal bootstrap that switches based on framework choice.

$framework = '{{ values.framework }}';

if ($framework === 'laravel') {
    // Minimal Laravel front controller expectation
    // The actual Laravel app would be installed via composer create-project in a richer template.
    echo "Laravel skeleton placeholder for {{ values.name }}";
    exit;
}

if ($framework === 'symfony') {
    require_once __DIR__ . '/../vendor/autoload.php';
    use Symfony\Component\HttpFoundation\Request;
    use Symfony\Component\HttpFoundation\Response;

    $request = Request::createFromGlobals();
    $response = new Response('Hello from Symfony skeleton {{ values.name }}', 200);
    $response->send();
    exit;
}

// plain
require_once __DIR__ . '/../vendor/autoload.php';
echo "Hello from plain PHP skeleton {{ values.name }}";
```

---

## `skeleton/Dockerfile` (only if `enableDocker`)

> Two approaches below. **A)** Single Dockerfile (quick start). **B)** Split base image + app image (faster CI builds at scale).

### A) Single, version‑agnostic Dockerfile (uses mlocati installer)

```Dockerfile
# Select PHP version at build time: --build-arg PHP_VERSION=8.3
ARG PHP_VERSION=${{ values.phpVersion }}
FROM php:${PHP_VERSION}-fpm AS base

# --- System deps commonly needed by Laravel & popular extensions ---
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libicu-dev libjpeg-dev libpng-dev libonig-dev \
    libfreetype6-dev libxml2-dev libssl-dev libpq-dev libcurl4-openssl-dev \
    nginx \
 && rm -rf /var/lib/apt/lists/*

# --- mlocati php-extension-installer ---
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

# Core extensions most Laravel apps use; trim as needed per project
RUN install-php-extensions \
    opcache \
    pdo_mysql \
    intl \
    gd \
    bcmath \
    exif \
    pcntl \
    sockets \
    redis

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Copy app first only composer files to leverage layer caching
COPY composer.json composer.lock* /app/
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist || true

# Then copy the rest of the source
COPY . /app

# Install prod deps properly now that sources exist (optimizes classmap)
RUN composer install --no-interaction --no-progress --prefer-dist --no-dev \
 && composer dump-autoload --optimize

# Sanity check: assuming frontend assets are built locally and committed
RUN test -f /app/public/index.php || (echo "Missing public/index.php" && exit 1)
# Uncomment if you enforce Vite assets presence
# RUN test -f /app/public/build/manifest.json || (echo "Missing public/build (run npm run build locally)" && exit 1)

# Nginx
COPY nginx/nginx.conf /etc/nginx/nginx.conf
EXPOSE 8080
CMD php-fpm -D && nginx -g 'daemon off;'
```

### B) Base image + App image (recommended for speed at scale)

**Base Dockerfile (build once per PHP version):**

```Dockerfile
# php-fpm base with common deps & extensions
ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm

RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libicu-dev libjpeg-dev libpng-dev \
    libfreetype6-dev libxml2-dev libssl-dev libpq-dev libcurl4-openssl-dev \
    nginx \
 && rm -rf /var/lib/apt/lists/*

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/
RUN install-php-extensions \
    opcache pdo_mysql intl gd bcmath exif pcntl sockets redis

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Tune php-fpm (optional)
# COPY docker/php.ini /usr/local/etc/php/php.ini
# COPY docker/php-fpm.d/zzz-pool.conf /usr/local/etc/php-fpm.d/zzz-pool.conf

WORKDIR /app
```

**Tag & push your base per version:**

```
# Example
# docker build -f Dockerfile.base --build-arg PHP_VERSION=8.3 -t ghcr.io/your-org/php-fpm-base:8.3 .
# docker push ghcr.io/your-org/php-fpm-base:8.3
```

**App Dockerfile (extends the base):**

```Dockerfile
# Build arg lets you switch base version quickly
ARG PHP_BASE=ghcr.io/your-org/php-fpm-base:8.3
FROM ${PHP_BASE}

WORKDIR /app
# Warm composer cache layer
COPY composer.json composer.lock* /app/
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist || true

# App code
COPY . /app

# Final install + optimize
RUN composer install --no-interaction --no-progress --prefer-dist --no-dev \
 && composer dump-autoload --optimize

# Optional: enforce prebuilt Vite assets
# RUN test -f /app/public/build/manifest.json || (echo "Missing public/build — run npm run build locally" && exit 1)

COPY nginx/nginx.conf /etc/nginx/nginx.conf
EXPOSE 8080
CMD php-fpm -D && nginx -g 'daemon off;'
```

**Notes**

* Keep **all heavy system libs and PHP extensions in the base**; change rarely → great cache reuse.
* For projects needing extra extensions, either:

  * bump your base with more extensions and retag (e.g., `8.3-gd-intl-redis`), or
  * add a small `install-php-extensions xdebug` step in the app Dockerfile for dev variants.
* If you eventually need Node for SSR/queues, add a sibling base like `php-fpm-node-base` built FROM `node:XX` + `php-fpm` via multi‑stage. Dockerfile

# PHP FPM + Nginx (s6 disabled for brevity; keep it simple)

ARG PHP_VERSION=${{ values.phpVersion }} FROM php:${PHP_VERSION}-fpm

# System deps

RUN apt-get update && apt-get install -y 
nginx 
git 
&& rm -rf /var/lib/apt/lists/*

# PHP extensions (common)

RUN docker-php-ext-install opcache

WORKDIR /app COPY . /app

# Composer

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer RUN composer install --no-interaction --no-progress

# Nginx config

COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Expose & simple CMD to run both

EXPOSE 8080 CMD php-fpm -D && nginx -g 'daemon off;'

````

---

## `skeleton/docker-compose.yml`

```yaml
version: "3.9"
services:
  app:
    build: .
    ports:
      - "8080:8080"
    volumes:
      - .:/app
````

---

## `skeleton/nginx/nginx.conf`

```nginx
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events { worker_connections  1024; }
http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;
  sendfile        on;
  keepalive_timeout  65;

  server {
    listen 8080;
    root /app/public;
    index index.php index.html;

    location / {
      try_files $uri /index.php?$query_string;
    }

    location ~ \.php$ {
      include snippets/fastcgi-php.conf;
      fastcgi_pass 127.0.0.1:9000;
    }
  }
}
```

---

## Helm chart (only if `enableHelm`)

### `skeleton/helm/Chart.yaml`

```yaml
apiVersion: v2
name: ${{ values.name }}
description: Helm chart for ${{ values.name }}
type: application
version: 0.1.0
appVersion: "0.1.0"
```

### `skeleton/helm/values.yaml`

```yaml
image:
  repository: ghcr.io/your-org/${{ values.name }}
  tag: latest
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
resources: {}
ingenress:
  enabled: true
  className: nginx
  host: ${{ values.name }}.local
```

### `skeleton/helm/templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ values.name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${{ values.name }}
  template:
    metadata:
      labels:
        app: ${{ values.name }}
    spec:
      containers:
        - name: app
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          ports:
            - containerPort: 8080
```

### `skeleton/helm/templates/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ${{ values.name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: ${{ values.name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
```

### `skeleton/helm/templates/ingress.yaml`

```yaml
{{- if .Values.ingenress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${{ values.name }}
  annotations: {}
spec:
  ingressClassName: {{ .Values.ingenress.className }}
  rules:
    - host: {{ .Values.ingenress.host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${{ values.name }}
                port:
                  number: {{ .Values.service.port }}
{{- end }}
```

> **Heads‑up:** `ingenress` is deliberately misspelled to show you can tweak values/keys freely; rename to `ingress` in your real chart if you prefer standard keys.

---

## CI

### GitHub Actions (`skeleton/.github/workflows/ci.yml` when `ciProvider == github`)

```yaml
name: CI
on:
  push:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '${{ values.phpVersion }}'
      - run: composer install --no-interaction --no-progress
      - run: php -v
```

### GitLab CI (`skeleton/.gitlab-ci.yml` when `ciProvider == gitlab`)

```yaml
stages: [build, test]
image: php:${{ values.phpVersion }}
cache:
  paths: [vendor/]
build:
  stage: build
  script:
    - apt-get update && apt-get install -y git unzip
    - php -v
    - curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    - composer install --no-interaction --no-progress
```

---

## TechDocs (only if `enableTechDocs`)

### `skeleton/mkdocs.yml`

```yaml
site_name: ${{ values.name }}
nav:
  - Home: index.md
plugins:
  - techdocs-core
```

### `skeleton/docs/index.md`

```md
# ${{ values.name }}

Welcome to the docs! Edit this page and run TechDocs generator.
```

---

## How to use

1. Put `template.yaml` and the `skeleton/` folder in a repo scanned by Backstage (e.g., `backstage-templates`).
2. In Backstage, **Create > Choose Template > PHP Service (Laravel‑ready)**.
3. Fill in parameters (framework, repo host, toggles), run.
4. After publish, the component is registered in the catalog and (optionally) ready to deploy with Docker/Helm.

### Notes & Options

* For a **full Laravel app**, you can replace `composer.json`/`public/index.php` with a `create-project laravel/laravel` step triggered via a `shell:run` action before `fetch:template`, but many orgs prefer keeping templates lightweight.
* Swap `publish:github` to `publish:gitlab` (or keep both with the conditional shown).
* Add ECR/GHCR build & push steps to CI if you ship containers.

---

## Troubleshooting

* If conditional steps (`if:`) aren’t supported in your Scaffolder version, pin a single publish action.
* Ensure `RepoUrlPicker` is enabled in your Backstage build (it is by default).
* For TechDocs, make sure `techdocs.publisher.type` matches your environment (e.g., `awsS3`).
