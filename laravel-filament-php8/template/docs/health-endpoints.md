# 🚑 Health Endpoints (Laravel Template)

This document describes the **minimal, intentional health endpoints** provided by the Laravel service template.

These endpoints exist to support:
- Kubernetes liveness and readiness probes
- Load balancer health checks
- Safe and predictable deployments

❗ This template **does NOT provide application-level metrics or APM by default**.
Observability beyond basic health is handled at the **platform level** (logs, Kubernetes signals, infrastructure monitoring).

---

## 🎯 Design Principles

- **Cheap first** – health checks must be fast and non-blocking
- **No false signals** – avoid endpoints that imply deep observability
- **Deployment-safe** – health should not block rollouts due to transient dependencies
- **Low noise** – no metrics or tracing unless they provide real diagnostic value

---

## 📍 Available Endpoints

### `/healthz` — Liveness (NGINX-level)

- Implemented directly in **NGINX**
- Does **not** execute PHP
- Does **not** depend on Laravel or application code

Typical implementation:
```nginx
location = /healthz {
    access_log off;
    add_header Content-Type text/plain;
    return 200 "ok\n";
}
```

**Used for:**
- Kubernetes liveness probes
- Load balancer health checks

This endpoint answers one question only:
> *Is the container responding to HTTP?*

---

### `/ready` — Readiness (static, file-based)

- Implemented as a **static PHP file** under `public/ready.php`
- Does **not** boot Laravel
- Does **not** check dependencies

Example:
```php
<?php
http_response_code(200);
header('Content-Type: text/plain; charset=utf-8');
echo "ready\n";
```

**Used for:**
- Kubernetes readiness probes
- Safe rollouts and scaling events

This endpoint answers:
> *Can this pod receive traffic right now?*

It is intentionally dumb and stable.

---

### `/up` — Framework Health (Laravel)

- Provided by Laravel itself
- Very lightweight framework boot check

Configured via `bootstrap/app.php`:
```php
health: '/up'
```

**Used for:**
- Basic framework validation
- Local debugging

---

## 🚫 What Is Intentionally NOT Included

This template intentionally does **not** include:

- `/metrics` (Prometheus-style metrics)
- Custom application metrics
- Distributed tracing
- APM-style instrumentation

Reason:
> Metrics without tracing or context tend to create **noise**, not clarity.

Observability signals that cannot explain *why* something is slow or broken are avoided by default.

---

## 📊 Observability Model (Platform-Owned)

This platform relies on:

- **Logs** (Loki + Grafana)
- **Kubernetes signals** (restarts, probe failures, events)
- **Infrastructure monitoring** (cluster, nodes, networking)

Application-level observability (metrics, tracing) may be introduced later as a **platform-wide decision**, not a per-service customization.

---

## 🧪 Probe Recommendations (Kubernetes)

### Default (recommended)
- **Liveness:** `/healthz`
- **Readiness:** `/ready`

### Why this works well
- Deployments are not blocked by DB/Redis hiccups
- Liveness remains cheap and reliable
- Failures are visible via logs and events

---

## 🧠 Summary

- Health endpoints are **not observability**
- This template provides only what is operationally necessary
- Logs remain the primary debugging signal
- Advanced observability is added **only when it delivers real value**

This approach keeps the platform:
- predictable
- debuggable
- low-noise
- scalable

---

*This document is part of the standard Backstage service template and is intended to evolve with the platform.*


---

## 🧭 Appendix: Future Tracing (RFC – NOT ENABLED)

> Status: **Design note only**
>
> This section documents a **possible future direction** for platform observability.
> It is **not enabled**, **not required**, and **not supported** at this time.

---

### 🎯 Motivation

Metrics alone cannot explain:
- why a request is slow
- where time is spent between API → DB → external calls
- which dependency caused a failure

If application-level observability is introduced in the future, it will be done
via **distributed tracing**, not ad-hoc metrics.

---

### 🧩 Proposed Stack (Future)

If adopted, the platform may standardize on:

- **OpenTelemetry (OTel)** — instrumentation & context propagation
- **Grafana Tempo** — trace storage backend
- **Grafana** — trace + log correlation
- **Loki** — logs (already in use)

This enables:
- request → DB → external call timelines
- latency attribution
- trace ↔ log correlation

---

### 🚫 Explicitly Out of Scope (Today)

The following are **not** provided by this template:

- OpenTelemetry SDKs
- Laravel tracing instrumentation
- Tempo collectors or agents
- Trace exporters
- Per-service configuration flags

No application code should assume tracing exists.

---

### 🧠 Platform Rule (If This Is Ever Enabled)

If tracing is introduced, it will be:

- platform-owned
- standardized
- documented once
- enabled deliberately

It will **not** be:
- opt-in per service
- partially enabled
- copy-pasted by teams

---

### 📌 Why This Is Not Enabled Yet

- Tracing without standards creates more noise than insight
- Instrumentation must be consistent across services
- Storage, retention, and cost must be understood first

Until those conditions are met, **logs remain the primary debugging signal**.

---

*This appendix exists to communicate direction — not obligation.*
