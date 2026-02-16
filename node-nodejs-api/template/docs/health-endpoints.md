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
// src/routes/health.js
const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
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
// src/routes/health.js
const express = require('express');
const router = express.Router();

// Readiness check
router.get('/ready', async (req, res) => {
  try {
    // Check database connection
    const dbHealthy = await checkDatabaseHealth();
    
    // Check cache connection
    const cacheHealthy = await checkCacheHealth();
    
    if (!dbHealthy || !cacheHealthy) {
      return res.status(503).json({
        status: 'not_ready',
        database: dbHealthy,
        cache: cacheHealthy,
        timestamp: new Date().toISOString(),
      });
    }
    
    res.json({
      status: 'ready',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    res.status(503).json({
      status: 'not_ready',
      error: err.message,
    });
  }
});

module.exports = router;
```

**Response (Healthy - 200)**:

```json
{
  "status": "ready",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**Response (Unhealthy - 503)**:

```json
{
  "status": "not_ready",
  "database": false,
  "cache": true,
  "timestamp": "2024-01-15T10:30:00Z"
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

---

## 🧪 Troubleshooting

### Health Check Failing in Kubernetes

```bash
# 1. Port-forward and test locally
kubectl port-forward pod/${{ values.app_name }}-xyz 3000:3000 -n ${{ values.app_name }}-stage
curl http://localhost:3000/health

# 2. Check pod logs
kubectl logs pod/${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage

# 3. Verify dependencies
kubectl exec pod/${{ values.app_name }}-xyz -n ${{ values.app_name }}-stage -- \
  node -e "console.log('Node is working')"
```

### Health Check Timeout

- Increase `timeoutSeconds` in probe config
- Check if dependencies (DB, cache) are accessible
- Review app startup time, increase `initialDelaySeconds`

---

## 📚 Reference

See [kubernetes.md](kubernetes.md) for:
- Port-forward commands
- Debugging pod issues
- Pod logs and events

