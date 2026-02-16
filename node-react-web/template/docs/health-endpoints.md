# Health Endpoints

Nginx serves a simple health endpoint at `/health` for Kubernetes probes and load balancer checks.

---

## 🏥 Health Endpoint

### GET `/health`

```bash
curl http://localhost/health
# Returns: ok (HTTP 200)
```

**Nginx Config**:
```nginx
location /health {
    default_type text/plain;
    return 200 "ok";
}
```

---

## ⚙️ Kubernetes Probes

### Liveness Probe
Checks if the container is still running.

```yaml
# charts/my-web/templates/deployment.yaml
livenessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3
```

### Readiness Probe
Checks if the app is ready for traffic.

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2
```

---

## 🧪 Testing

### Local Docker

```bash
# Start container
docker run -p 8080:80 my-web:latest

# Test health
curl http://localhost:8080/health
```

### Kubernetes

```bash
# Port-forward to service
kubectl port-forward svc/my-web 8080:80 -n my-web-stage

# Test health
curl http://localhost:8080/health

# Check probe status
kubectl describe pod <pod-name> -n my-web-stage
# Look for: Liveness and Readiness sections
```

---

## 📊 Monitoring

```bash
# View logs
kubectl logs deployment/my-web -n my-web-stage

# Check events
kubectl get events -n my-web-stage --sort-by='.lastTimestamp'

# Pod status
kubectl get pods -n my-web-stage -o wide
```

---

## ❌ Troubleshooting

### Health check failing
1. **Pod not running**: `kubectl get pods -n my-web-stage`
2. **Port mismatch**: Verify Nginx listens on 80, container port is 80
3. **Network policy**: Check if NetworkPolicy blocks port 80
4. **Check logs**: `kubectl logs pod/<name> -n my-web-stage`

### Probes timeout
- Increase `initialDelaySeconds` if app needs time to start
- Decrease `periodSeconds` to check more frequently
- Check pod resource limits (CPU/memory)

---

See [deployment.md](deployment.md) for full deployment setup.

