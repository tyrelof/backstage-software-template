✅ Final /metrics endpoint — upgraded version

Add this to routes/web.php:

```php
<?php

use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Cache;

Route::get('/metrics', function () {
    $lines = [];

    // -------------------------
    // 1) APP UP
    // -------------------------
    $lines[] = '# HELP app_up Application liveness indicator (1 = running)';
    $lines[] = '# TYPE app_up gauge';
    $lines[] = 'app_up 1';


    // -------------------------
    // 2) APP INFO
    // -------------------------
    $app  = config('app.name', 'laravel-app');
    $env  = config('app.env', 'local');
    $ver  = config('app.version', 'unknown');   // optional

    $lines[] = '';
    $lines[] = '# HELP app_info Application metadata';
    $lines[] = '# TYPE app_info gauge';
    $lines[] = sprintf('app_info{app="%s",env="%s",version="%s"} 1', $app, $env, $ver);


    // -------------------------
    // 3) Request Counter (simple, non-persistent)
    //    - resets on container restart (fine for containers)
    // -------------------------
    static $counter = 0;
    $counter++;

    $lines[] = '';
    $lines[] = '# HELP app_requests_total Total metrics endpoint hits';
    $lines[] = '# TYPE app_requests_total counter';
    $lines[] = "app_requests_total $counter";


    // -------------------------
    // 4) Database Connectivity Metric
    // -------------------------
    $dbStatus = 0;
    try {
        DB::connection()->getPdo();
        $dbStatus = 1;
    } catch (\Throwable $e) {}

    $lines[] = '';
    $lines[] = '# HELP app_database_up Database connectivity (1=ok, 0=down)';
    $lines[] = '# TYPE app_database_up gauge';
    $lines[] = "app_database_up $dbStatus";


    // -------------------------
    // 5) Redis Connectivity Metric
    // -------------------------
    $redisStatus = 0;

    try {
        if (config('database.redis.default.host')) {
            Redis::connection()->ping();
            $redisStatus = 1;
        }
    } catch (\Throwable $e) {}

    $lines[] = '';
    $lines[] = '# HELP app_redis_up Redis connectivity (1=ok, 0=down)';
    $lines[] = '# TYPE app_redis_up gauge';
    $lines[] = "app_redis_up $redisStatus";


    // -------------------------
    // 6) Horizon Queue Size (if Redis available)
    // -------------------------
    $queueSize = 0;
    if ($redisStatus === 1) {
        try {
            $queueSize = Redis::llen('queues:default') ?? 0;
        } catch (\Throwable $e) {}
    }

    $lines[] = '';
    $lines[] = '# HELP app_queue_default_length Length of default queue (if using queue)';
    $lines[] = '# TYPE app_queue_default_length gauge';
    $lines[] = "app_queue_default_length $queueSize";


    // -------------------------
    // Final Output
    // -------------------------
    $body = implode("\n", $lines) . "\n";
    return new Response($body, 200, ['Content-Type' => 'text/plain; charset=utf-8']);
});
```

🔥 What new metrics did we add?
✔ 1. app_up — liveness gauge

Confirms the route executed.

✔ 2. app_info — metadata

Labels: app, env, version

✔ 3. app_requests_total — simple counter

Counts /metrics scrapes.
Good for debugging Prometheus scraping behavior.

✔ 4. app_database_up — DB connection gauge

1 if DB connection works

0 if down

Never throws exceptions

✔ 5. app_redis_up — Redis ping gauge

Detects Redis status

Returns 0/1

Safe for apps that don’t use Redis (stays 0)

✔ 6. app_queue_default_length

Shows how many jobs in default queue
(only if Redis is alive)

🎯 No Composer packages needed

We avoided:

promphp/prometheus_client_php

laravel-prometheus-exporter

You don’t need those unless you want Histograms, Summaries, or auto-instrumentation.

This remains SIMPLE and TEMPLATE-FRIENDLY.