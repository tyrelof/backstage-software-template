.PHONY: help install dev test lint format clean run build docker-build docker-run docker-clean

help:
	@echo "Available commands:"
	@echo "  make install      - Install dependencies"
	@echo "  make dev          - Install development dependencies"
	@echo "  make test         - Run tests"
	@echo "  make lint         - Run code quality checks"
	@echo "  make format       - Format code (black, isort)"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make run          - Run application locally"
	@echo "  make build        - Build Docker image"
	@echo "  make docker-run   - Run Docker container"
	@echo "  make docker-clean - Clean Docker artifacts"

install:
	pip install --upgrade pip
	pip install -r requirements.txt

dev: install
	pip install pytest pytest-cov pytest-asyncio black ruff isort

test:
	pytest src/tests/ -v --cov=src --cov-report=html --cov-report=term

lint:
	ruff check src/
	black src/ --check --quiet
	isort src/ --check-only --quiet

format:
	black src/
	isort src/
	ruff check src/ --fix

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache .coverage htmlcov dist build *.egg-info .mypy_cache .ruff_cache

run:
	uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

build:
	docker build -t ${{ values.app_name }}:latest -t ${{ values.app_name }}:$$(git rev-parse --short HEAD) .

docker-run: build
	docker run -it -p 8000:8000 ${{ values.app_name }}:latest

docker-clean:
	docker rmi ${{ values.app_name }}:latest ${{ values.app_name }}:$$(git rev-parse --short HEAD) 2>/dev/null || true
