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
🔹 Inner nginx = baked into the app image (nginx/snippets → /etc/nginx/conf.d/).
🔹 Outer nginx = local-only proxy defined by docker-compose (nginx/local/default.conf → reverse proxy to laravel container).


✅ 1. /healthz — Nginx-only (for K8s)

Very fast, does not touch Laravel or PHP.
Use this inside your container nginx OR in dev proxy nginx.

nginx/snippets/healthz.conf
location = /healthz {
    return 200 "ok\n";
    add_header Content-Type text/plain;
}


This is what K8s liveness/readiness probes should use.

✅ 2. /health — Laravel route (for app dependency checks)

Copy this into routes/web.php.

routes/web.php
```php
<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

Route::get('/health', function () {

    $status = [
        'app'    => 'ok',
        'time'   => now()->toIso8601String(),
        'checks' => [],
    ];

    // ------------------------------
    // 1) Database Check
    // ------------------------------
    try {
        DB::connection()->getPdo();
        $status['checks']['database'] = 'ok';
    } catch (\Throwable $e) {
        $status['checks']['database'] = 'error';
        $status['checks']['database_error'] = app()->environment('local') ? $e->getMessage() : 'hidden';
    }

    // ------------------------------
    // 2) Redis Check
    // ------------------------------
    try {
        if (config('database.redis.default.host')) {
            Redis::connection()->ping();
            $status['checks']['redis'] = 'ok';
        } else {
            $status['checks']['redis'] = 'skipped';
        }
    } catch (\Throwable $e) {
        $status['checks']['redis'] = 'error';
        $status['checks']['redis_error'] = app()->environment('local') ? $e->getMessage() : 'hidden';
    }

    // ------------------------------
    // 3) Reverb Check (optional)
    // ------------------------------
    $reverbEnabled = env('REVERB_ENABLED', false);
    $reverbHost    = env('REVERB_HOST', 'reverb');
    $reverbPort    = (int) env('REVERB_PORT', 8080);

    if ($reverbEnabled) {
        $connected = false;
        try {
            $timeout = 0.3;
            $socket = @fsockopen($reverbHost, $reverbPort, $errno, $errstr, $timeout);
            if ($socket) {
                fclose($socket);
                $connected = true;
            }
        } catch (\Throwable $e) {}

        $status['checks']['reverb'] = $connected ? 'ok' : 'error';
        if (!$connected) {
            $status['checks']['reverb_details'] = app()->environment('local')
                ? "Cannot connect to {$reverbHost}:{$reverbPort}"
                : 'hidden';
        }
    } else {
        $status['checks']['reverb'] = 'disabled';
    }

    // ------------------------------
    // HTTP Status Code
    // ------------------------------
    $httpStatus = 200;
    foreach ($status['checks'] as $check => $value) {
        if ($value === 'error') {
            $httpStatus = 503;
            break;
        }
    }

    return response()->json($status, $httpStatus);
});
```

✔ Automatically hides sensitive errors on production
✔ Full DB / Redis / Reverb checks
✔ Returns 503 if anything is down
✔ Lightweight enough for monitoring tools

✅ 3. .env additions (for Reverb apps)

Add these to your template's .env:
```env
REVERB_ENABLED=false
REVERB_HOST=reverb
REVERB_PORT=8080
```
If the app doesn’t use Reverb → leave disabled.
✅ 4. Recommended Documentation for Your Template

(You can put this in docs/index.md or README)

Health Endpoints Overview

| Path       | Layer          | Purpose                        | Used by                     |
| ---------- | -------------- | ------------------------------ | --------------------------- |
| `/healthz` | Nginx (no PHP) | Liveness/Readiness probe       | Kubernetes / NLB (optional) |
| `/health`  | Laravel route  | Checks database, redis, reverb | Developers / monitoring     |

Kubernetes Probes Example:
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: http

readinessProbe:
  httpGet:
    path: /healthz
    port: http
```

Local Dev:
http://localhost/healthz → quick check
http://localhost/health → full diagnostic