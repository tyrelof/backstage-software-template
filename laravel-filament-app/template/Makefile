# ------------------------------------------
# CONFIGURATION
# ------------------------------------------
DOCKER_COMPOSE  := docker-compose.yml
PHP_SERVICE     ?= laravel
PHP_IMAGE_NAME  ?= $(shell docker compose -f $(DOCKER_COMPOSE) images -q $(PHP_SERVICE))
NODE_IMAGE_NAME ?= node:20.19.4-slim
APP_SRC_DIR     ?= ./src
.DEFAULT_GOAL   := help

.PHONY: \
    compose-run compose-up compose-down compose-restart compose-logs compose-clean \
    frontend-install frontend-build frontend-dev \
    vendor migrate seed artisan \
    status push help

# ------------------------------------------
# HELP COMMAND
# ------------------------------------------
help:  ## Show all make commands with descriptions
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "🛠️  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ------------------------------------------
# DOCKER COMPOSE CONTROLS
# ------------------------------------------
compose-run:  ## 🚀 Build and start containers (optionally a specific service)
	@echo "🚀 Building and starting containers..."
	@echo "SERVICE variable is: [$(SERVICE)]"
	@# Attempt ECR login first
	@echo "🔑 Logging in to public ECR..."
	@if ! aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/h1y8m9v5 > /dev/null 2>&1; then \
		echo "❌ Failed to login to public ECR. Your token may have expired or your user lacks permissions."; \
		echo "📞 Contact system admin or DevOps to refresh credentials."; \
		exit 1; \
	fi
	@# Proceed with docker-compose build/up
	@if [ -z "$(SERVICE)" ]; then \
		echo "🛠️  Building all services..."; \
		if [ "$(FORCE_BUILD)" = "1" ]; then \
			docker compose -f $(DOCKER_COMPOSE) build --no-cache --pull; \
		else \
			docker compose -f $(DOCKER_COMPOSE) build; \
		fi && \
		docker compose -f $(DOCKER_COMPOSE) up -d; \
	else \
		if docker compose -f $(DOCKER_COMPOSE) config --services | grep -wq "$(SERVICE)"; then \
			echo "🛠️  Building only service: $(SERVICE)"; \
			if [ "$(FORCE_BUILD)" = "1" ]; then \
				docker compose -f $(DOCKER_COMPOSE) build --no-cache --pull "$(SERVICE)"; \
			else \
				docker compose -f $(DOCKER_COMPOSE) build "$(SERVICE)"; \
			fi && \
			docker compose -f $(DOCKER_COMPOSE) up -d "$(SERVICE)"; \
		else \
			echo "❌ Service '$(SERVICE)' not found in docker-compose.yml"; \
			exit 1; \
		fi \
	fi

compose-up:  ## Start containers
	@echo "📦 Starting containers..."
	docker compose -f $(DOCKER_COMPOSE) up -d

compose-down:  ## Stop containers
	@echo "🛑 Stopping containers..."
	docker compose -f $(DOCKER_COMPOSE) down

compose-restart: compose-down compose-up  ## Restart containers

compose-logs:  ## Tail logs
	@echo "📜 Fetching logs..."
	docker compose -f $(DOCKER_COMPOSE) logs -f

compose-clean:  ## Prune unused Docker data
	@echo "🧹 Cleaning up Docker..."
	docker system prune -f

# ------------------------------------------
# FRONTEND
# ------------------------------------------
frontend-install:  ## 🖌 Install frontend assets
	@echo "🛠 Installing frontend dependencies..."
	docker run --rm --init \
	    -v "$(shell pwd)/src:/var/www/html" \
	    -w /var/www/html $(NODE_IMAGE_NAME) \
	    sh -c "npm install --no-audit --no-fund --verbose || exit 1"

frontend-build:  ## 🖌 Build frontend assets
	@echo "🛠 Building frontend..."
	docker run --rm --init \
	    -v "$(shell pwd)/src:/var/www/html" \
	    -w /var/www/html $(NODE_IMAGE_NAME) \
	    sh -c "npm run build || exit 1"

frontend-dev:  ## 🖌 Run frontend dev server (use CMD to override)
	@echo "🛠 Running frontend dev: $(CMD)"
	@if [ -z "$(CMD)" ]; then \
		CMD="dev"; \
	fi; \
	docker run --rm -it --init \
	    -v "$(shell pwd)/src:/var/www/html" \
	    -w /var/www/html \
	    -p 5173:5173 \
	    $(NODE_IMAGE_NAME) \
	    sh -c "npm run $$CMD"
		
# ------------------------------------------
# PHP CLI helper
# ------------------------------------------
vendor: $(APP_SRC_DIR)/composer.json $(APP_SRC_DIR)/composer.lock
	@echo "📦 Installing PHP dependencies..."
	@if [ -z "$$GITLAB_TOKEN" ]; then \
		echo "❌ GITLAB_TOKEN is not set."; \
		echo ""; \
		echo "👉 Please run:"; \
		echo "   export GITLAB_TOKEN=glxxx-xxxx-xxxxxxxxxxxxx"; \
		echo ""; \
		exit 1; \
	fi
	docker run --rm \
		-v "$(shell pwd)/src:/var/www/html" \
		-w /var/www/html \
		$(PHP_IMAGE_NAME) \
		sh -c "composer config --global gitlab-token.nexus.nmscreative.com $$GITLAB_TOKEN && composer install --ignore-platform-reqs --no-interaction --prefer-dist"
	@touch vendor

migrate: vendor  ## 🧪 Run artisan migrations inside laravel service
	@echo "🛠 Running artisan migrate in $(PHP_SERVICE)..."
	docker compose -f $(DOCKER_COMPOSE) exec -T $(PHP_SERVICE) php artisan migrate --force

seed: vendor  ## 🌱 Run artisan db:seed inside laravel service
	@echo "🛠 Running artisan db:seed in $(PHP_SERVICE)..."
	docker compose -f $(DOCKER_COMPOSE) exec -T $(PHP_SERVICE) php artisan db:seed

artisan: vendor  ## 🖥 Run any artisan command inside laravel service
	@echo "🛠 Running artisan command in $(PHP_SERVICE): $(CMD)"
	@if [ -z "$(CMD)" ]; then \
		echo "❌ Please provide CMD variable, e.g. make artisan CMD='config:clear'"; \
		exit 1; \
	fi
	docker compose -f $(DOCKER_COMPOSE) exec -T $(PHP_SERVICE) php artisan $(CMD)

# ------------------------------------------
# GIT HELPERS
# ------------------------------------------
status:  ## 🔍 Show project environment, Git info, Docker, and more
	@echo ""
	@echo "🔍 Project Status"
	@echo "────────────────────────────────────────────"
	@echo "🌐 Environment  : \033[36mlocal\033[0m"
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