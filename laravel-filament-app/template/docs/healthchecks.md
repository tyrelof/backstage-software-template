## Traffic & Healthcheck Flow

```mermaid
flowchart LR
    C[Client / Browser] --> NLB[AWS NLB/ALB]
    NLB --> ING[NGINX Ingress Controller]
    ING --> SVC[App Service (ClusterIP)]
    SVC --> POD[Laravel Pod (nginx + php-fpm)]

    subgraph Laravel Pod
      NGINX[nginx]
      PHP[php-fpm + Laravel]
      NGINX --> PHP
    end

    %% Healthchecks
    K8S[Kubernetes (kubelet)] -->|/healthz| POD
    MON[Monitoring / Dev] -->|/health| PHP
```

Health Endpoints

- /healthz
  - Served by: nginx inside the pod
  - Used by: Kubernetes liveness/readiness, optional LB checks
  - Behavior: always returns 200 ok if container is alive

- /health
  - Served by: Laravel (routes/web.php)
  - Used by: developers / monitoring tools
  - Behavior: returns JSON with checks for DB, Redis, Reverb, etc.


That’s ready to paste.

---

## 2️⃣ Minimal `/metrics` endpoint (Prometheus-style starter)

This is a **super basic** Prometheus text endpoint.  
Not real app metrics yet, but gives you a valid scrape target immediately.

Add this **below your `/health` route** in `routes/web.php`:

```php
use Illuminate\Http\Response;

Route::get('/metrics', function () {
    // Simple example metrics in Prometheus text format
    $lines = [];

    // 1) app_up gauge – 1 if this code runs
    $lines[] = '# HELP app_up Application liveness indicator';
    $lines[] = '# TYPE app_up gauge';
    $lines[] = 'app_up 1';

    // 2) app_info – label-only metric with static info
    $appName = config('app.name', 'laravel-app');
    $env     = config('app.env', 'local');
    $lines[] = '';
    $lines[] = '# HELP app_info Static application info';
    $lines[] = '# TYPE app_info gauge';
    $lines[] = sprintf('app_info{app="%s",env="%s"} 1', $appName, $env);

    $body = implode("\n", $lines) . "\n";

    return new Response($body, 200, ['Content-Type' => 'text/plain; charset=utf-8']);
});
```

Prometheus can scrape /metrics and you’ll see:
```text
app_up 1
app_info{app="YourApp",env="local"} 1
```
Later, if your devs want real metrics, they can replace this with a proper package but your infra side is already ready.

3️⃣ Helm toggles for health + metrics
3.1 Extend values.yaml

Add this block (or merge with what you already have):
```yaml
health:
  enabled: true        # master switch for probes
  path: /healthz       # nginx-level health endpoint
  liveness:
    enabled: true
  readiness:
    enabled: true

metrics:
  enabled: false       # enable if you want Prometheus scraping
  path: /metrics
  port: http           # must match containerPort name (e.g. "http")
  scrapeInterval: 30s  # optional, for annotations
```

You already have:
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
We’ll make those conditional.

3.2 Wire toggles in deployment.yaml

In chart/${{values.app_name}}/templates/deployment.yaml, inside the container spec, replace your static probes with conditional blocks like:
```yaml
        readinessProbe:
        {{- if and .Values.health.enabled .Values.health.readiness.enabled }}
          httpGet:
            path: {{ .Values.health.path | default "/healthz" }}
            port: {{ .Values.service.portName | default "http" | quote }}
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3
        {{- end }}

        livenessProbe:
        {{- if and .Values.health.enabled .Values.health.liveness.enabled }}
          httpGet:
            path: {{ .Values.health.path | default "/healthz" }}
            port: {{ .Values.service.portName | default "http" | quote }}
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3
        {{- end }}
```

If you don’t have service.portName, you can hardcode "http" since your containerPort usually has that name.

3.3 Prometheus annotations via Helm

Still in deployment.yaml, under spec.template.metadata:
```yaml
  template:
    metadata:
      labels:
        {{- include "${{values.app_name}}.selectorLabels" . | nindent 8 }}
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- if .Values.metrics.enabled }}
        prometheus.io/scrape: "true"
        prometheus.io/path: {{ .Values.metrics.path | default "/metrics" | quote }}
        prometheus.io/port: {{ .Values.metrics.port | default "http" | quote }}
        prometheus.io/scrape_interval: {{ .Values.metrics.scrapeInterval | default "30s" | quote }}
        {{- end }}
```

Now:
- Set metrics.enabled: true → Prometheus (or any scraper respecting those annotations) will scrape /metrics on port http.
- Set metrics.enabled: false → no annotations, no scraping.

3.4 How your toggles behave
- Turn off all K8s probes:
```yaml
health:
  enabled: false
```
- Only readiness, no liveness:
```yaml
health:
  enabled: true
  liveness:
    enabled: false
  readiness:
    enabled: true
```
- Enable Prometheus:
```yaml
metrics:
  enabled: true
  path: /metrics
  port: http
```

Auto-detect whether Redis/Reverb is configured

This means:

- If Redis config exists → check it

- If not → mark redis: disabled

- If Reverb env flag is false → mark reverb: disabled

This requires zero work from devs.
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
    // 2) Redis Check (auto-disable if not configured)
    // ------------------------------
    $redisConfigured = config('database.redis.default.host') !== null;

    if ($redisConfigured) {
        try {
            Redis::connection()->ping();
            $status['checks']['redis'] = 'ok';
        } catch (\Throwable $e) {
            $status['checks']['redis'] = 'error';
            $status['checks']['redis_error'] = app()->environment('local') ? $e->getMessage() : 'hidden';
        }
    } else {
        $status['checks']['redis'] = 'disabled';
    }

    // ------------------------------
    // 3) Reverb Check (auto-disabled via env)
    // ------------------------------
    $reverbEnabled = env('REVERB_ENABLED', false);

    if ($reverbEnabled) {
        $reverbHost = env('REVERB_HOST', 'reverb');
        $reverbPort = (int) env('REVERB_PORT', 8080);
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
    foreach ($status['checks'] as $value) {
        if ($value === 'error') {
            $httpStatus = 503;
            break;
        }
    }

    return response()->json($status, $httpStatus);
});
```
Results:

- If Redis isn’t configured → "redis": "disabled"

- If Reverb isn’t enabled → "reverb": "disabled"

Zero errors. Zero noise. Clean.

REDIS_ENABLED=false
REVERB_ENABLED=false