# Nginx Layout (Local vs Prod)

This template uses **two nginx layers**, but for different purposes.

---

## 1. Inner Nginx (Inside the Laravel App Image)

The Laravel app image contains:

- nginx
- php-fpm
- the Laravel codebase

During the Docker build, we copy optional nginx snippets into the image:

```dockerfile
# Optional Nginx overrides (dir kept by .gitkeep; may be empty)
COPY nginx/snippets/ /etc/nginx/conf.d/
```

Directory layout:
```text
nginx/
  snippets/
    healthz.conf.sample
    livewire.conf.sample
    reports.conf.sample
```

These files are intended for inner nginx only.
To customize nginx in the app image, you can:

- copy a sample file,
-  edit it,
-  rebuild the image.

In production, traffic eventually hits this inner nginx inside the pod:
```text
INTERNET → NLB → NGINX INGRESS → APP SERVICE → [LARAVEL POD: nginx + php-fpm]
```

2. Outer Nginx (Local-Dev Proxy Only)

For local development, we run a separate nginx container as a lightweight reverse proxy in front of the Laravel container.

Flow in local dev:
```text
BROWSER → docker-compose nginx → laravel container (nginx + php-fpm)
```

Directory layout:
```text
nginx/
  local/
    default.conf      # used only by the docker-compose nginx proxy
```

Example docker-compose.yml snippet:
```yaml
services:
  laravel:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: filament
    expose:
      - "80"            # inner nginx port
    networks:
      - shared-network
    depends_on:
      - mariadb
      - redis

  nginx:
    image: nginx:1.27-alpine
    container_name: filament-nginx
    ports:
      - "80:80"         # local access on http://localhost
    volumes:
      - ./nginx/local/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - laravel
    networks:
      - shared-network
```

Example nginx/local/default.conf:
```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://laravel;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /healthz {
        return 200 "ok\n";
    }
}
```
```txt
🔹 Inner nginx = baked into the app image (nginx/snippets → /etc/nginx/conf.d/).
🔹 Outer nginx = local-only proxy defined by docker-compose (nginx/local/default.conf → reverse proxy to laravel container).
```