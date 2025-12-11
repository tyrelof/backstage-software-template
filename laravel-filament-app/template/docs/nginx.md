# Nginx Layout & Usage

This template uses **two different nginx layers**:

1. **Inner nginx** – lives _inside_ the Laravel app image (nginx + PHP-FPM).
2. **Outer nginx (local only)** – runs as a separate container and reverse-proxies to the app for local development.

The goal: in dev, you always hit `http://localhost` and let Docker/nginx handle the wiring.

---

## Directory Layout

```text
nginx/
  local/
    default.conf              # used by docker-compose for local proxy
  snippets/
    healthz.conf.sample       # example extra locations for inner nginx
    livewire.conf.sample
    reports.conf.sample
```

- nginx/local/default.conf → outer nginx, only for local dev.
- nginx/snippets/*.sample → inner nginx examples you can copy into the base nginx image or infra repos.

Local Nginx (Outer Proxy)

For local dev we run an extra nginx container that proxies to the laravel service.

docker-compose.yml
```yaml
services:
  laravel:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: filament
    expose:
      - "80"          # nginx INSIDE the container
    networks:
      - shared-network
    depends_on:
      - mariadb
      - redis

  nginx:
    image: nginx:1.27-alpine
    container_name: filament-nginx
    ports:
      - "80:80"       # bind to localhost:80
    volumes:
      - ./nginx/local/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - laravel
    networks:
      - shared-network
```