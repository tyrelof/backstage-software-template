# ============================================================
# Makefile - FastAPI Template
# Requires: Docker, Docker Compose
# ============================================================

.PHONY: help install dev lint test start build clean audit docker-build docker-run docker-clean \
	install-docker dev-docker lint-docker test-docker start-docker build-docker \
	compose-up compose-down compose-logs compose-build compose-ps

# -------|---------------------
# Config
# -------|---------------------
PY_IMAGE ?= python:3.11-slim
APP_PORT ?= 8000
APP_IMAGE ?= ${{ values.app_name }}:dev
PIP_CACHE_DIR ?= /app/.cache/pip
PROJECT_DIR := $(shell pwd)

define PY_DOCKER_RUN
docker run --rm \
	-v "$(PROJECT_DIR):/app" \
	-w /app \
	-e PIP_CACHE_DIR="$(PIP_CACHE_DIR)" \
	$(PY_IMAGE) \
	sh -lc
endef

# -------|---------------------
# Help
# -------|---------------------
help:  ## Show all make commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-18s %s\n", $$1, $$2}'

# -------|---------------------
# Default workflow
# -------|---------------------
install: install-docker  ## Install dependencies
install-docker:  ## Install dependencies inside Docker
	@$(PY_DOCKER_RUN) "pip install --upgrade pip && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt"

dev: dev-docker  ## Run dev server with hot reload
dev-docker:  ## Run dev server inside Docker
	@docker run --rm -it \
	  -v "$(PROJECT_DIR):/app" \
	  -w /app \
	  -p $(APP_PORT):8000 \
	  $(PY_IMAGE) \
	  sh -lc "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt >/dev/null && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"

lint: lint-docker  ## Run code quality checks
lint-docker:  ## Run code quality checks inside Docker
	@$(PY_DOCKER_RUN) "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt >/dev/null && ruff check app/ && black app/ --check --quiet && isort app/ --check-only --quiet"

test: test-docker  ## Run tests
test-docker:  ## Run tests inside Docker
	@$(PY_DOCKER_RUN) "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt >/dev/null && pytest tests/ -v --cov=app --cov-report=term --cov-report=xml"

start: start-docker  ## Run app
start-docker:  ## Run app inside Docker
	@$(PY_DOCKER_RUN) "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt >/dev/null && uvicorn app.main:app --host 0.0.0.0 --port 8000"

build: build-docker  ## Build for production
build-docker:  ## Build Docker image
	docker build -t $(APP_IMAGE) .

# -------|---------------------
# Security checks
# -------|---------------------
audit: audit-docker  ## Run pip audit
audit-docker:  ## Run pip audit inside Docker
	@$(PY_DOCKER_RUN) "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt pip-audit >/dev/null && pip-audit --desc"

clean:  ## Remove build artifacts
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache .coverage coverage.xml htmlcov dist build *.egg-info .mypy_cache .ruff_cache
	rm -rf .cache/pip 2>/dev/null || true

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
	docker run --rm -it -p $(APP_PORT):8000 $(APP_IMAGE)

docker-clean:  ## Remove Docker images
	docker rmi $(APP_IMAGE) ${{ values.app_name }}:$$(git rev-parse --short HEAD) 2>/dev/null || true
