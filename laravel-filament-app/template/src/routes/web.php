<?php

use Illuminate\Http\Response;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

// ---------------------------------------------------------
// /metrics - Prometheus metrics endpoint
// ---------------------------------------------------------
Route::get('/metrics', function () {
    $lines = [];

    // -------------------------
    // 0) Common context
    // -------------------------
    $appName = config('app.name', 'laravel-app');
    $env     = config('app.env', 'local');
    $version = config('app.version', 'unknown'); // optional, can set in config/app.php


    // -------------------------
    // 1) app_up – is this code running?
    // -------------------------
    $lines[] = '# HELP app_up Application liveness indicator (1 = running)';
    $lines[] = '# TYPE app_up gauge';
    $lines[] = 'app_up 1';


    // -------------------------
    // 2) app_info – static app metadata
    // -------------------------
    $lines[] = '';
    $lines[] = '# HELP app_info Application metadata (labels only)';
    $lines[] = '# TYPE app_info gauge';
    $lines[] = sprintf(
        'app_info{app="%s",env="%s",version="%s"} 1',
        $appName,
        $env,
        $version
    );


    // -------------------------
    // 3) PHP memory usage
    // -------------------------
    $memUsage = memory_get_usage(true);       // current usage (bytes)
    $memPeak  = memory_get_peak_usage(true); // peak usage (bytes)

    $lines[] = '';
    $lines[] = '# HELP app_php_memory_usage_bytes Current PHP memory usage in bytes';
    $lines[] = '# TYPE app_php_memory_usage_bytes gauge';
    $lines[] = "app_php_memory_usage_bytes {$memUsage}";

    $lines[] = '';
    $lines[] = '# HELP app_php_memory_peak_usage_bytes Peak PHP memory usage in bytes';
    $lines[] = '# TYPE app_php_memory_peak_usage_bytes gauge';
    $lines[] = "app_php_memory_peak_usage_bytes {$memPeak}";


    // -------------------------
    // 4) Config cache status
    // -------------------------
    $configCached = app()->configurationIsCached() ? 1 : 0;

    $lines[] = '';
    $lines[] = '# HELP app_config_cached Whether Laravel config is cached (1=yes, 0=no)';
    $lines[] = '# TYPE app_config_cached gauge';
    $lines[] = "app_config_cached {$configCached}";


    // -------------------------
    // 5) Route count
    // -------------------------
    $routeCount = 0;
    try {
        $routeCount = count(Route::getRoutes());
    } catch (\Throwable $e) {
        $routeCount = 0;
    }

    $lines[] = '';
    $lines[] = '# HELP app_routes_total Total number of registered routes';
    $lines[] = '# TYPE app_routes_total gauge';
    $lines[] = "app_routes_total {$routeCount}";


    // -------------------------
    // 6) Database connectivity + latency
    // -------------------------
    $dbUp      = 0;
    $dbLatency = 0.0;

    try {
        $t0 = microtime(true);
        // Simple lightweight query; works on MySQL/MariaDB/Postgres
        DB::select('SELECT 1');
        $dbLatency = microtime(true) - $t0;
        $dbUp      = 1;
    } catch (\Throwable $e) {
        $dbUp      = 0;
        $dbLatency = 0.0;
    }

    $lines[] = '';
    $lines[] = '# HELP app_database_up Database connectivity (1=ok, 0=down)';
    $lines[] = '# TYPE app_database_up gauge';
    $lines[] = "app_database_up {$dbUp}";

    $lines[] = '';
    $lines[] = '# HELP app_database_query_time_seconds Time for a simple DB query in seconds';
    $lines[] = '# TYPE app_database_query_time_seconds gauge';
    $lines[] = "app_database_query_time_seconds {$dbLatency}";


    // -------------------------
    // 7) Redis connectivity + latency
    // -------------------------
    $redisUp      = 0;
    $redisLatency = 0.0;

    try {
        $redisConfig = config('database.redis.default', null);
        $redisConfigured = is_array($redisConfig) && !empty($redisConfig['host'] ?? null);

        if ($redisConfigured) {
            $t0 = microtime(true);
            Redis::connection()->ping();
            $redisLatency = microtime(true) - $t0;
            $redisUp      = 1;
        }
    } catch (\Throwable $e) {
        $redisUp      = 0;
        $redisLatency = 0.0;
    }

    $lines[] = '';
    $lines[] = '# HELP app_redis_up Redis connectivity (1=ok, 0=down)';
    $lines[] = '# TYPE app_redis_up gauge';
    $lines[] = "app_redis_up {$redisUp}";

    $lines[] = '';
    $lines[] = '# HELP app_redis_ping_time_seconds Time for Redis PING in seconds';
    $lines[] = '# TYPE app_redis_ping_time_seconds gauge';
    $lines[] = "app_redis_ping_time_seconds {$redisLatency}";


    // -------------------------
    // 8) Simple in-process scrape counter
    //    (per PHP-FPM worker, resets on restart)
    // -------------------------
    static $scrapeCounter = 0;
    $scrapeCounter++;

    $lines[] = '';
    $lines[] = '# HELP app_metrics_scrapes_total Number of times /metrics was scraped (per worker)';
    $lines[] = '# TYPE app_metrics_scrapes_total counter';
    $lines[] = "app_metrics_scrapes_total {$scrapeCounter}";


    // -------------------------
    // Final response
    // -------------------------
    $body = implode("\n", $lines) . "\n";

    return new Response($body, 200, ['Content-Type' => 'text/plain; charset=utf-8']);
});


// ---------------------------------------------------------
// /health - Deep app health (DB, Redis, Reverb)
// ---------------------------------------------------------
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
    $redisConfig = config('database.redis.default', null);
    $redisConfigured = is_array($redisConfig) && !empty($redisConfig['host'] ?? null);

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
    // IMPORTANT: env() returns strings; use filter_var so "false" becomes false.
    $reverbEnabled = filter_var(env('REVERB_ENABLED', false), FILTER_VALIDATE_BOOL);

    if ($reverbEnabled) {
        $reverbHost = env('REVERB_HOST', 'reverb');
        $reverbPort = (int) env('REVERB_PORT', 8080);
        $connected  = false;

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
