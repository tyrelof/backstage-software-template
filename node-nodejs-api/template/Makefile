# ============================================================
# Makefile - Node.js API Template
# Requires: Docker
# ============================================================

.PHONY: help install dev lint test start clean docker-build docker-run docker-clean \
	install-docker dev-docker lint-docker test-docker start-docker \
	audit trivy sbom security audit-docker trivy-docker sbom-docker \
	compose-up compose-down compose-logs compose-build compose-ps

# -----------------------------
# Config
# -----------------------------
NODE_IMAGE ?= node:20-alpine
TRIVY_IMAGE ?= aquasec/trivy:0.49.1
APP_PORT ?= 3000
APP_IMAGE ?= ${{ values.app_name }}:dev
SBOM_FILE ?= sbom.cdx.json
PROJECT_DIR := $(shell pwd)

define NODE_DOCKER_RUN
docker run --rm \
	-v "$(PROJECT_DIR):/app" \
	-w /app \
	$(NODE_IMAGE) \
	sh -lc
endef

# -----------------------------
# Help
# -----------------------------
help:  ## Show all make commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-18s %s\n", $$1, $$2}'

# -----------------------------
# Default workflow
# -------|---------------------
install: install-docker  ## Install dependencies
install-docker:  ## Install dependencies inside Docker
	@$(NODE_DOCKER_RUN) "npm ci"

dev: compose-up  ## Run dev server (uses docker-compose)
dev-docker:  ## Run dev server inside Docker (one-off container)
	@docker run --rm -it \
	  -v "$(PROJECT_DIR):/app" \
	  -w /app \
	  -p $(APP_PORT):3000 \
	  $(NODE_IMAGE) \
	  sh -lc "npm ci && npm run dev"

lint: lint-docker  ## Run lint
lint-docker:  ## Run lint inside Docker
	@$(NODE_DOCKER_RUN) "npm ci && npm run lint"

test: test-docker  ## Run tests
test-docker:  ## Run tests inside Docker
	@$(NODE_DOCKER_RUN) "npm ci && npm run test --if-present"

start: start-docker  ## Run app
start-docker:  ## Run app inside Docker
	@docker run --rm -it \
	  -v "$(PROJECT_DIR):/app" \
	  -w /app \
	  -p $(APP_PORT):3000 \
	  $(NODE_IMAGE) \
	  sh -lc "npm ci && npm start"

# -----------------------------
# Security checks
# -----------------------------
audit: audit-docker  ## Run npm audit
audit-docker:  ## Run npm audit inside Docker
	@$(NODE_DOCKER_RUN) "npm ci && npm audit --omit=dev"

trivy: trivy-docker  ## Run Trivy image scan
trivy-docker: docker-build  ## Run Trivy scan inside Docker
	@docker run --rm \
	  $(TRIVY_IMAGE) \
	  image --severity HIGH,CRITICAL --ignore-unfixed --no-progress $(APP_IMAGE)

sbom: sbom-docker  ## Generate SBOM
sbom-docker: docker-build  ## Generate SBOM via Trivy inside Docker
	@docker run --rm \
	  -v "$(PROJECT_DIR):/work" \
	  -w /work \
	  $(TRIVY_IMAGE) \
	  image --format cyclonedx --output "$(SBOM_FILE)" $(APP_IMAGE)

security: audit trivy sbom  ## Run all security checks

clean:  ## Remove build artifacts
	rm -rf node_modules

# -------|---------------------
# Docker Compose workflow
# -------|---------------------
compose-up:  ## Start services with Docker Compose
	docker compose up -d

compose-down:  ## Stop and remove Docker Compose services
	docker compose down

compose-logs:  ## View Docker Compose logs
	docker compose logs -f

compose-build:  ## Build services with Docker Compose
	docker compose build

compose-ps:  ## Show Docker Compose service status
	docker compose ps

# -------|---------------------
# Docker workflow
# -------|---------------------
docker-build:  ## Build Docker image
	docker build -t $(APP_IMAGE) -t ${{ values.app_name }}:$$(git rev-parse --short HEAD) .

docker-run: docker-build  ## Run Docker image
	docker run --rm -it -p $(APP_PORT):3000 $(APP_IMAGE)

docker-clean:  ## Remove Docker images
	docker rmi $(APP_IMAGE) ${{ values.app_name }}:$$(git rev-parse --short HEAD) 2>/dev/null || true
