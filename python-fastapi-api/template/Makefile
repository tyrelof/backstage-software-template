# ============================================================
# Makefile - FastAPI Template
# Requires: Docker
# Optional: local python/pip for *-local targets
# ============================================================

.PHONY: help install dev test lint format clean run build docker-build docker-run docker-clean status push \
        install-docker dev-docker test-docker lint-docker format-docker run-docker \
        install-local dev-local test-local lint-local format-local

# -----------------------------
# Config
# -----------------------------
PY_IMAGE ?= python:3.11-slim
APP_PORT ?= 8000

# If you want a consistent tag for local docker image builds:
APP_IMAGE ?= ${{ values.app_name }}:dev

# Cache pip downloads on host to speed up repeated runs
PIP_CACHE_DIR ?= /app/.cache/pip

# Mount project into container
PROJECT_DIR := $(shell pwd)

# Base docker run wrapper for python tooling
define PY_DOCKER_RUN
docker run --rm \
  -v "$(PROJECT_DIR):/app" \
  -w /app \
  -e PIP_CACHE_DIR="$(PIP_CACHE_DIR)" \
  $(PY_IMAGE) \
  sh -lc
endef

# -----------------------------
# Help
# -----------------------------
help:  ## Show all make commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "🛠️  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ============================================================
# Docker-powered workflow (DEFAULT)
# ============================================================

install: install-docker  ## Install dependencies (Docker-powered)
install-docker:  ## Install dependencies inside Docker
	@echo "🐳 Installing dependencies in Docker ($(PY_IMAGE))..."
	@$(PY_DOCKER_RUN) "python -V && pip install --upgrade pip && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt"

dev: dev-docker  ## Install development dependencies (Docker-powered)
dev-docker:  ## Install dev deps inside Docker (pytest/black/ruff/isort)
	@echo "🐳 Installing dev dependencies in Docker ($(PY_IMAGE))..."
	@$(PY_DOCKER_RUN) "python -V && pip install --upgrade pip && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt && pip install --cache-dir \"$$PIP_CACHE_DIR\" pytest pytest-cov pytest-asyncio black ruff isort"

lint: lint-docker  ## Run code quality checks (Docker-powered)
lint-docker:  ## Lint inside Docker (ruff + black --check + isort --check-only)
	@echo "🐳 Running lint in Docker ($(PY_IMAGE))..."
	@$(PY_DOCKER_RUN) "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt ruff black isort >/dev/null && ruff check src/ && black src/ --check --quiet && isort src/ --check-only --quiet"

format: format-docker  ## Format code (Docker-powered)
format-docker:  ## Format inside Docker (isort + black + ruff --fix)
	@echo "🐳 Formatting code in Docker ($(PY_IMAGE))..."
	@$(PY_DOCKER_RUN) "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt ruff black isort >/dev/null && isort src/ && black src/ && ruff check src/ --fix"

test: test-docker  ## Run tests with coverage (Docker-powered)
test-docker:  ## Test inside Docker (pytest + coverage xml)
	@echo "🐳 Running tests in Docker ($(PY_IMAGE))..."
	@$(PY_DOCKER_RUN) "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$$PIP_CACHE_DIR\" -r requirements.txt pytest pytest-cov pytest-asyncio >/dev/null && pytest src/tests/ -v --cov=src --cov-report=term --cov-report=xml"

run: run-docker  ## Run application locally (Docker-powered)
run-docker:  ## Run uvicorn inside Docker (binds to 0.0.0.0:8000)
	@echo "🐳 Running app in Docker ($(PY_IMAGE)) on port $(APP_PORT)..."
	@docker run --rm -it \
	  -v "$(PROJECT_DIR):/app" \
	  -w /app \
	  -p $(APP_PORT):8000 \
	  $(PY_IMAGE) \
	  sh -lc "pip install --upgrade pip >/dev/null && pip install --cache-dir \"$(PIP_CACHE_DIR)\" -r requirements.txt uvicorn >/dev/null && uvicorn src.main:app --reload --host 0.0.0.0 --port 8000"

# ============================================================
# Optional: Local Python workflow (fallback/manual)
# ============================================================

install-local:  ## Install dependencies locally (requires local python/pip)
	pip install --upgrade pip
	pip install -r requirements.txt

dev-local: install-local  ## Install development dependencies locally
	pip install pytest pytest-cov pytest-asyncio black ruff isort

lint-local:  ## Run code quality checks locally
	ruff check src/
	black src/ --check --quiet
	isort src/ --check-only --quiet

format-local:  ## Format code locally
	black src/
	isort src/
	ruff check src/ --fix

test-local:  ## Run tests locally with coverage
	pytest src/tests/ -v --cov=src --cov-report=term --cov-report=xml

# ============================================================
# Docker image workflow (your app Dockerfile)
# ============================================================

build: docker-build  ## Build Docker image (uses Dockerfile)
docker-build:  ## Build app image from Dockerfile
	docker build -t $(APP_IMAGE) -t ${{ values.app_name }}:$$(git rev-parse --short HEAD) .

docker-run: docker-build  ## Run Docker container (app image)
	docker run -it -p $(APP_PORT):8000 $(APP_IMAGE)

docker-clean:  ## Clean Docker artifacts
	docker rmi $(APP_IMAGE) ${{ values.app_name }}:$$(git rev-parse --short HEAD) 2>/dev/null || true

# ============================================================
# Cleanup
# ============================================================

clean:  ## Remove build artifacts
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache .coverage coverage.xml htmlcov dist build *.egg-info .mypy_cache .ruff_cache
	rm -rf .cache/pip 2>/dev/null || true

# ------------------------------------------
# GIT HELPERS
# ------------------------------------------
status:  ## 🔍 Show project environment, Git info, Docker, and more
	@echo ""
	@echo "🔍 Project Status"
	@echo "────────────────────────────────────────────"
	@echo "🌐 Environment  : \033[36mlocal\033[0m"
	@echo "🐳 Py Image     : \033[36m$(PY_IMAGE)\033[0m"
	@echo "🌿 Git Branch   : \033[1;32m$$(git rev-parse --abbrev-ref HEAD)\033[0m"
	@echo "🔢 Commit Hash  : \033[1;33m$$(git rev-parse --short HEAD)\033[0m"
	@echo "📝 Last Commit  : \033[1;35m$$(git log -1 --pretty=%B | tr -d '\n')\033[0m"
	@echo "👤 Committer    : \033[1;34m$$(git log -1 --pretty=format:'%an <%ae>')\033[0m"
	@echo "🌐 Remote Repo  : \033[1;36m$$(git config --get remote.origin.url)\033[0m"
	@echo "🧼 Clean Repo   : \033[1;31m$$(if git diff --quiet && git diff --cached --quiet; then echo Yes; else echo No; fi)\033[0m"
	@echo "☸️  K8s Context  : \033[1;36m$$(KUBECONFIG=$$(getent passwd $${SUDO_USER:-$$USER} | cut -d: -f6)/.kube/config kubectl config current-context 2>/dev/null || echo N/A)\033[0m"
	@echo "🐳 Docker PS    :"
	@docker ps --format "{{.Names}}|{{.Status}}" 2>/dev/null | awk -F"|" '{printf "  - \033[0;36m%s\033[0m (%s)\n", $$1, $$2}' || echo "  🔴 Docker not running"
	@echo "🕒 Timestamp    : \033[1;90m$$(date '+%Y-%m-%d %H:%M:%S')\033[0m"
	@echo "👤 User         : \033[1;36m$$(whoami)\033[0m"
	@echo "💻 Hostname     : \033[1;36m$$(hostname)\033[0m"
	@echo "────────────────────────────────────────────"
	@echo ""

push:  ## 🔼 Git commit & push current branch
	@echo "🔼 Running Git push helper script..."
	chmod +x scripts/git-push.sh && ./scripts/git-push.sh
