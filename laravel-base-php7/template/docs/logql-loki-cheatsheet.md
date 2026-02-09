# Loki / LogQL Cheat Sheet (Kubernetes)

Fast, **label-first** queries for application logs in **Grafana Explore** using **Loki**.  
Rule of thumb: **namespace → container/pod → text filter**.

---

## Quick Start

- **Grafana → Explore → Data source: Loki**
- Always filter using **labels first**
- Avoid querying `{}` (entire cluster) unless debugging Loki itself

---

## Core Labels You’ll Use Most

| Label | Meaning | Example |
|------|--------|--------|
| `namespace` | Kubernetes namespace (best first filter) | `namespace="payments"` |
| `pod` | Pod name (often changes, use regex) | `pod=~"payments-.*"` |
| `container` | Container inside the pod | `container="app"` |
| `app` / `app_kubernetes_io_name` | App label (depends on chart/agent) | `app="payments"` |
| `cluster` / `job` | Multi-cluster / scrape identifier (optional) | `cluster="core-us-east-2"` |

---

## Most‑Used Queries (Copy / Paste)

### All logs in a namespace
```logql
{namespace="my-namespace"}
```

### Namespace + container
```logql
{namespace="my-namespace", container="app"}
```

### Namespace + pod (regex)
```logql
{namespace="my-namespace", pod=~"my-app-.*"}
```

### Find errors (simple)
```logql
{namespace="my-namespace"} |= "ERROR"
```

### Exclude noise
```logql
{namespace="my-namespace"} != "health"
```

### NGINX / Ingress example (HTTP 5xx)
```logql
{namespace="my-namespace", container="nginx"} |= " 50"
```

---

## Language‑Agnostic Error / Warning Filters

Most applications log similar keywords regardless of language.

### Errors (broad)
```logql
{namespace="x"} |~ "(?i)error|exception|panic|fatal|segfault"
```

Common terms:
- `ERROR`, `error`
- `exception`, `traceback`, `stacktrace`
- `panic`, `fatal`, `segfault`

---

### Warnings / retries / timeouts
```logql
{namespace="x"} |~ "(?i)warn|timeout|retry|backoff|slow"
```

Common terms:
- `WARN`, `warning`
- `timeout`, `retry`
- `deprecated`, `slow`, `backoff`, `circuit`

---

### HTTP 5xx
```logql
{namespace="x"} |~ " 50[0-4]"
```

---

### Database issues
```logql
{namespace="x"} |~ "(?i)deadlock|connections|refused|lock wait|EOF"
```

---

### Notes on operators
- `|=` → exact substring match
- `|~` → regex match
- `(?i)` → case‑insensitive regex

---

## JSON Logs (If Your App Logs JSON)

### Error level
```logql
{namespace="my-namespace"}
| json
| level="error"
```

### HTTP status >= 500
```logql
{namespace="my-namespace"}
| json
| status >= 500
```

---

## Metrics‑Style Queries (Dashboards & Alerts)

### Error rate
```logql
rate({namespace="my-namespace"} |~ "(?i)error|exception" [5m])
```

### Log volume
```logql
count_over_time({namespace="my-namespace"}[5m])
```

---

## Troubleshooting Checklist

- Start with **namespace-only** query
- Check log agent is running (`promtail` / `alloy` / `fluent-bit`)
- Verify Grafana Loki datasource URL
- Confirm time range in Explore (Last 15m / 1h)
- Inspect a log line → **Labels** (adjust queries to real labels)

---

## Platform Rule (Print This)

> **Labels first, text second.  
> Namespace is king.  
> Regex is your friend.**

---
