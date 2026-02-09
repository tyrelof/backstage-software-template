# Health Endpoints

Health check endpoints are critical for Kubernetes deployments. They provide liveness and readiness probes.

## Liveness Probe

**Endpoint**: `GET /health`

Used by Kubernetes to determine if the container is alive and should be restarted.

**Status Code**: 200 (healthy), 503 (unhealthy)

**Response**:
```json
{
  "status": "healthy",
  "app": "${{ values.app_name }}"
}
```

**Kubernetes Configuration**:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

## Readiness Probe

**Endpoint**: `GET /ready`

Used by Kubernetes to determine if the container is ready to accept traffic. This should check dependencies like database connections.

**Status Code**: 200 (ready), 503 (not ready)

**Response**:
```json
{
  "status": "ready",
  "app": "${{ values.app_name }}"
}
```

**Kubernetes Configuration**:
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

## Monitoring

Health endpoints are typically monitored by:

1. **Kubernetes**: For pod lifecycle management
2. **Load Balancers**: For traffic routing
3. **Monitoring Systems**: For alerting (Prometheus, Datadog, New Relic)
4. **Uptime Monitors**: For external monitoring

## Best Practices

1. Keep health checks lightweight and fast
2. Include dependency checks in readiness probe
3. Use appropriate failure thresholds
4. Monitor health endpoint response times
5. Return consistent response format
