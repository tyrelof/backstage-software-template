# Health Endpoints & Monitoring

## Overview

Health endpoints allow platforms and monitoring systems to verify application status:

- **Liveness** (`/health`) - Is the process alive? If not, Kubernetes restarts container
- **Readiness** (`/health/ready`) - Can it handle traffic? If not, Kubernetes removes from load balancer

---

## 🏥 Health Endpoints

### GET /health

Liveness probe - **confirms the process is running**:

```javascript
// app/api/health/route.ts
export async function GET() {
  return Response.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
  })
}
```

**Response**:

```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**Kubernetes Configuration**:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Fails if**: Process is hung, memory exhausted, or unresponsive

---

### GET /health/ready

Readiness probe - **confirms it can process requests**:

```javascript
// app/api/health/ready/route.ts
import { checkDatabaseConnection } from '@/lib/db'
import { checkRedisConnection } from '@/lib/redis'

export async function GET() {
  const dbHealthy = await checkDatabaseConnection()
  const redisHealthy = await checkRedisConnection()
  
  if (!dbHealthy || !redisHealthy) {
    return Response.json(
      { status: "not_ready", database: dbHealthy, redis: redisHealthy },
      { status: 503 }
    )
  }
  
  return Response.json({
    status: "ready",
    timestamp: new Date().toISOString(),
  })
}
```

**Response (Healthy)**:

```json
{
  "status": "ready",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**Response (Unhealthy)**:

```json
{
  "status": "not_ready",
  "database": false,
  "redis": true
}
```

**Kubernetes Configuration**:

```yaml
readinessProbe:
  httpGet:
    path: /health/ready
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
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
curl http://localhost:3000/health
curl http://localhost:3000/health/ready

# Watch responses (repeat every 2 seconds)
watch -n 2 curl http://localhost:3000/health
```

### Kubernetes Testing

```bash
# Port-forward to local
kubectl port-forward svc/${{ values.app_name }} 3000:3000 -n ${{ values.app_name }}-stage

# In another terminal
curl http://localhost:3000/health
curl http://localhost:3000/health/ready

# Check probe results in pod status
kubectl describe pod ${{ values.app_name }}-abc123 -n ${{ values.app_name }}-stage

# Watch pod status changes
kubectl get pods -n ${{ values.app_name }}-stage -w
```

### Performance Testing

```bash
# Load test health endpoint (1000 requests)
ab -n 1000 -c 10 http://localhost:3000/health

# Monitor response times
wrk -t 4 -c 100 -d 30s http://localhost:3000/health
```

---

## 📊 Probe Configuration

### Timing Parameters

```yaml
probe:
  initialDelaySeconds: 30  # Wait before first check
  periodSeconds: 10        # Check every N seconds
  timeoutSeconds: 5        # Fail if no response in N seconds
  failureThreshold: 3      # Fail after N consecutive failures
```

**Examples**:

```yaml
# Aggressive (quick failure detection)
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 2

# Conservative (reduce false positives)
readinessProbe:
  httpGet:
    path: /health/ready
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
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
kubectl exec ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage -- curl http://localhost:3000/health
```

### Readiness Probe Failed

Pod not receiving traffic:

```bash
# 1. Check readiness status
kubectl get pods -n ${{ values.app_name }}-stage

# 2. View detailed status
kubectl describe pod ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage | grep -A 5 "Readiness"

# 3. Check dependencies
kubectl exec ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage -- curl http://postgres:5432

# 4. View logs for dependency errors
kubectl logs ${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage
```

### Endpoints Not Responding

```bash
# 1. Verify application is running
kubectl get pods -n ${{ values.app_name }}-stage
Status should be "Running"

# 2. Check logs for startup errors
kubectl logs deployment/${{ values.app_name }} -n ${{ values.app_name }}-stage --tail 100

# 3. Port-forward and test directly
kubectl port-forward pod/${{ values.app_name }}-xyz 3000:3000 -n ${{ values.app_name }}-stage &
curl http://localhost:3000/health
kill %1

# 4. Verify port is correct
kubectl get deployment ${{ values.app_name }} -n ${{ values.app_name }}-stage -o yaml | grep -A 5 "containerPort"
```

---

## 📈 Monitoring & Alerting

### Prometheus Metrics

Export health status as metrics (optional):

```typescript
// lib/metrics.ts
import client from 'prom-client'

const healthCheck = new client.Gauge({
  name: 'app_health_check_total',
  help: 'Application health check status (1=healthy, 0=unhealthy)',
})

const dependencyCheck = new client.Gauge({
  name: 'app_dependency_status',
  help: 'Dependency status (1=ok, 0=failing)',
  labelNames: ['dependency'],
})

export async function updateHealthMetrics() {
  const dbHealthy = await checkDatabaseConnection()
  const redisHealthy = await checkRedisConnection()
  
  healthCheck.set(dbHealthy && redisHealthy ? 1 : 0)
  dependencyCheck.set({ dependency: 'database' }, dbHealthy ? 1 : 0)
  dependencyCheck.set({ dependency: 'redis' }, redisHealthy ? 1 : 0)
}
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

```typescript
async function checkDatabaseConnection(): Promise<boolean> {
  try {
    const connection = await sql`SELECT 1`
    return !!connection
  } catch (error) {
    console.error('Database health check failed:', error)
    return false
  }
}
```

### Check Redis Connection

```typescript
import Redis from 'ioredis'

const redis = new Redis(process.env.REDIS_URL!)

async function checkRedisConnection(): Promise<boolean> {
  try {
    await redis.ping()
    return true
  } catch (error) {
    console.error('Redis health check failed:', error)
    return false
  }
}
```

### Check External API

```typescript
async function checkExternalAPI(): Promise<boolean> {
  try {
    const response = await fetch('https://api.example.com/health', {
      timeout: 5000,
    })
    return response.ok
  } catch (error) {
    console.error('External API health check failed:', error)
    return false
  }
}
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

❌ **Don't**:
- Make health checks too complex
- Check non-critical services in liveness probe
- Return 500 for expected failures (use 503 for readiness)
- Block startup waiting for optional dependencies
- Disable probes in production

---

## 📚 Reference

See [kubernetes.md](kubernetes.md) for:
- Port-forward commands
- Debugging pod issues
- Pod logs and events

