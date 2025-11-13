# Quick checklist (works for both nginx/traefik controllers)
- Name your container and Service port "http" (your probes reference port: http).
- Add TLS in values.yaml (so the chart renders a proper Ingress with cert-manager).
- Set the ingress class (nginx or traefik) and a couple of annotations.

Minimal, correct values.yaml for NGINX
```yaml
replicaCount: 2

image:
  repository: tyrelfecha/python-app
  pullPolicy: IfNotPresent
  tag: "6dd6a6"

service:
  type: ClusterIP
  port: 5000
  name: http                 # <-- ensure Service port is named "http"

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: le-prod
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    # (optional) common NGINX tweaks:
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
  hosts:
    - host: python-app.test.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: python-app-tls
      hosts:
        - python-app.test.com

livenessProbe:
  httpGet:
    path: /api/v1/healthz
    port: http               # <-- matches named port

readinessProbe:
  httpGet:
    path: /api/v1/healthz
    port: http
```

Make sure your templates align
templates/service.yaml
```yaml
spec:
  ports:
    - name: http                  # <-- name it "http"
      port: {{ .Values.service.port }}
      targetPort: http
```
templates/deployment.yaml
```yaml
containers:
  - name: app
    ports:
      - name: http                # <-- expose named port
        containerPort: 5000
```

## Minimal, correct values.yaml for Traefik
Only a couple of changes vs NGINX:
```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    cert-manager.io/cluster-issuer: le-prod
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
  hosts:
    - host: python-app.test.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: python-app-tls
      hosts:
        - python-app.test.com
```
Tip (Traefik): if you later add middlewares (rate-limit/IP allow), reference them with
traefik.ingress.kubernetes.io/router.middlewares: ingress-allow-office@kubernetescrd.

## Do you “need” TLS in values?
- If you want HTTPS + cert-manager (recommended), yes: include the tls: block and the cert-manager.io/cluster-issuer annotation. External-DNS will create the DNS record, cert-manager will issue the cert and store it in python-app-tls.
- If you truly want HTTP only (not recommended), omit tls: and remove the cert-manager annotation.

## External DNS / Cloudflare
Since your ingress controller is the only LoadBalancer, keeping:
```sh
external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
```

## Common gotchas to avoid
- Probes failing because the Service/Container port isn’t named "http" while probes use port: http. Name the ports as shown.
- Wrong ingress class: set ingress.className to exactly nginx or traefik, matching your installed controller.
- Missing ClusterIssuer: ensure le-prod exists (you already have it in your addons stack).