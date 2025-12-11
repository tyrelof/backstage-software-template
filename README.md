# Web App Runtime Images

A collection of base / runtime container images I use for web applications.

Each image lives under `images/<name>` with its own Dockerfile and README.

## Images

- `php-laravel-s6-base`
  - PHP 8.3 FPM + nginx + s6-overlay
  - Laravel-friendly (storage perms, caches, entrypoint compatible with workers)
  - Can run standalone or be used as a base image

Planned:

- `php-laravel-app-example` – example Laravel app image that uses `php-laravel-s6-base`
- `python-flask-gunicorn` – Python base runtime for Flask apps
- `node-nestjs-runtime` – Node app runtime image
