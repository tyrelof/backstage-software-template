# Health Endpoints & Monitoring

## Overview

Health endpoints allow platforms and monitoring systems to verify application status:

- **Liveness** (`/health`) - Is the process alive? If not, Kubernetes restarts container
- **Readiness** (`/health/ready`) - Can it handle traffic? If not, Kubernetes removes from load balancer

---

## 🏥 Health Endpoints

### GET /health

Liveness probe - **confirms the process is running**:

```python
# app/routers/health.py
from fastapi import APIRouter
from datetime import datetime

router = APIRouter()

@router.get("/health", tags=["Health"])
async def health():
    """Liveness probe - confirms the process is running"""
    return {
        "status": "healthy",
        "service": "api-service",
        "timestamp": datetime.utcnow().isoformat(),
    }
```

**Response**:

```json
{
  "status": "healthy",
  "service": "api-service",
  "timestamp": "2024-01-15T10:30:00.123456"
}
```

**Kubernetes Configuration**:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3
```

**Fails if**: Process is hung, memory exhausted, or unresponsive

---

### GET /health/ready

Readiness probe - **confirms it can process requests**:

```python
# app/routers/health.py
@router.get("/health/ready", tags=["Health"])
async def readiness():
    """Readiness probe - confirms it can process requests"""
    checks = {
        "database": await check_database(),
        "redis_cache": await check_redis(),
        "external_api": await check_external_services(),
    }
    
    ready = all(checks.values())
    status_code = 200 if ready else 503
    
    return {
        "status": "ready" if ready else "not_ready",
        "timestamp": datetime.utcnow().isoformat(),
        "dependencies": checks,
    }, status_code

async def check_database() -> bool:
    """Verify database connectivity"""
    try:
        # Ping database (example: PostgreSQL)
        await db.connection.execute("SELECT 1")
        return True
    except Exception as e:
        logger.error(f"Database check failed: {e}")
        return False

async def check_redis() -> bool:
    """Verify Redis cache connectivity"""
    try:
        await redis_client.ping()
        return True
    except Exception as e:
        logger.error(f"Redis check failed: {e}")
        return False

async def check_external_services() -> bool:
    """Verify external service availability"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get("https://api.example.com/status", timeout=5)
            return response.status_code == 200
    except Exception as e:
        logger.error(f"External service check failed: {e}")
        return False
```

**Response (Healthy)**:

```json
{
  "status": "ready",
  "timestamp": "2024-01-15T10:30:00.123456",
  "dependencies": {
    "database": true,
    "redis_cache": true,
    "external_api": true
  }
}
```

**Response (Unhealthy)**:

```json
{
  "status": "not_ready",
  "timestamp": "2024-01-15T10:30:00.123456",
  "dependencies": {
    "database": false,
    "redis_cache": true,
    "external_api": true
  }
}
```

**Kubernetes Configuration**:

```yaml
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 2
```

**Fails if**: Database down, cache unavailable, or dependency not responding

---

## 🧪 Testing Locally

### Development Server

```bash
# Start development server
make dev

# In another terminal, test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/health/ready

# Watch responses (repeat every 2 seconds)
watch -n 2 curl http://localhost:8000/health/ready
```

### Kubernetes Testing

```bash
# Port-forward to local
kubectl port-forward svc/${{ values.app_name }} 8000:8000 -n ${{ values.app_name }}-stage

# In another terminal
curl http://localhost:8000/health
curl http://localhost:8000/health/ready

# Check probe results in pod status
kubectl describe pod ${{ values.app_name }}-abc123 -n ${{ values.app_name }}-stage

# Watch pod status changes
kubectl get pods -n ${{ values.app_name }}-stage -w
```

### Performance Testing

```bash
# Load test health endpoint (1000 requests)
ab -n 1000 -c 10 http://localhost:8000/health

# Monitor response times
wrk -t 4 -c 100 -d 30s http://localhost:8000/health
```

---

## 📊 Probe Configuration

### Timing Parameters

```yaml
probe:
  initialDelaySeconds: 10  # Wait before first check
  periodSeconds: 30        # Check every N seconds (liveness)
  timeoutSeconds: 5        # Fail if no response in N seconds
  failureThreshold: 3      # Fail after N consecutive failures
```

**Examples**:

```yaml
# Aggressive (quick failure detection)
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 2

# Conservative (reduce false positives)
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 2
```

---

## 🔍 Debugging Failed Probes

### Liveness Probe Failed

Pod keeps restarting:

```bash
# 1. Check probe configuration
kubectl describe pod ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage | grep -A 5 "Liveness"

# 2. View previous pod logs
kubectl logs ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage --previous

# 3. Check if process is actually running
kubectl exec ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage -- ps aux

# 4. Test health endpoint directly
kubectl exec ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage -- \
  python -m httpx GET http://localhost:8000/health
```

### Readiness Probe Failed

Pod not receiving traffic:

```bash
# 1. Check readiness status
kubectl get pods -n ${{ values.app_name }}-stage

# 2. View detailed status
kubectl describe pod ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage | grep -A 5 "Readiness"

# 3. Check dependencies
kubectl exec ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage -- python -c \
  "from app.routers.health import check_database; import asyncio; print(asyncio.run(check_database()))"

# 4. View logs for dependency errors
kubectl logs ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage
```

### Endpoints Not Responding

```bash
# 1. Verify application is running
kubectl get pods -n ${{ values.app_name }}-stage
# Status should be "Running"

# 2. Check logs for startup errors
kubectl logs deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage --tail 100

# 3. Port-forward and test directly
kubectl port-forward pod/${{ values.app_name }}-xyz 8000:8000 -n ${{ values.app_name }}-stage &
curl http://localhost:8000/health
kill %1

# 4. Verify port is correct
kubectl get deployment ${{ values.app_name }} -n ${{ values.app_name }}-stage -o yaml | grep -A 5 "containerPort"
```

---

## 📈 Monitoring & Alerting

### Prometheus Metrics

Export health status as metrics (optional):

```python
# app/main.py
from prometheus_client import Counter, Gauge
from datetime import datetime

health_checks = Counter(
    'health_checks_total',
    'Total health checks',
    ['endpoint', 'status']
)

dependencies_healthy = Gauge(
    'dependencies_healthy',
    'Dependency health status',
    ['dependency']
)

@router.get("/health/ready")
async def readiness():
    checks = await run_all_checks()
    ready = all(checks.values())
    
    health_checks.labels(
        endpoint='ready',
        status='pass' if ready else 'fail'
    ).inc()
    
    for dep, status in checks.items():
        dependencies_healthy.labels(dependency=dep).set(1 if status else 0)
    
    status_code = 200 if ready else 503
    return {
        "status": "ready" if ready else "not_ready",
        "dependencies": checks,
    }, status_code
```

### CloudWatch Monitoring

Get Kubernetes pod health from CloudWatch:

```bash
# View pod status in CloudWatch Container Insights
aws cloudwatch list-metrics \
  --namespace ContainerInsights \
  --metric-name PodRestartCount
```

### Alerting Rules

```yaml
# Example Prometheus alert
alert: PodCrashLoopBackOff
expr: increase(kube_pod_container_status_restarts_total[15m]) > 5
annotations:
  summary: "Pod {{ $labels.pod }} is restarting frequently"
  action: "Check /health endpoint logs"
```

---

## 🔧 Common Health Check Patterns

### Check Database Connection

```python
import asyncio
from sqlalchemy.ext.asyncio import AsyncSession

async def check_database() -> bool:
    """Check PostgreSQL/MySQL connection"""
    try:
        async with SessionLocal() as session:
            await session.execute("SELECT 1")
        return True
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        return False
```

### Check Redis Connection

```python
import redis.asyncio as redis

redis_client = redis.from_url("redis://localhost:6379")

async def check_redis() -> bool:
    """Check Redis connection"""
    try:
        await redis_client.ping()
        return True
    except Exception as e:
        logger.error(f"Redis health check failed: {e}")
        return False
```

### Check External API

```python
import httpx

async def check_external_api() -> bool:
    """Check external API availability"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://api.example.com/health",
                timeout=5.0
            )
            return response.status_code == 200
    except Exception as e:
        logger.error(f"External API health check failed: {e}")
        return False
```

---

## 📊 Health Status Codes

| Endpoint | Status | Meaning |
|----------|--------|---------|
| `/health` | 200 | Healthy - process is alive |
| `/health` | 500 | Unhealthy - process not responding |
| `/health/ready` | 200 | Ready - can handle traffic |
| `/health/ready` | 503 | Not Ready - dependencies unavailable |
| `/health/ready` | 500 | Error - internal failure |

---

## 🧠 Best Practices

✅ **Do**:
- Keep health checks fast (< 1 second)
- Include dependency checks in readiness probe
- Use same logic for local and k8s testing
- Log health check failures with details
- Monitor probe failures in Prometheus
- Use async/await for non-blocking I/O

❌ **Don't**:
- Make health checks too complex
- Check non-critical services in liveness probe
- Return 500 for expected failures (use 503 for readiness)
- Block startup waiting for optional dependencies
- Disable probes in production
- Execute long-running queries in health checks

---

## 📚 Reference

See [api.md](api.md) for general API endpoint documentation.

