---

title: NGINX Ingress on EKS: Install & Operations (Playbook)
slug: eks-ingress-nginx-install-operations
last_updated: 2025-10-09
version: v1.0
owners: [platform, devops]
status: stable
tags: [eks, ingress, nginx, nlb, tls, cert-manager, externaldns, cloudflare]
----------------------------------------------------------------------------

# NGINX Ingress on EKS: Install & Operations (Playbook)

**Last updated:** 2025-10-09 (Asia/Manila)

## Scope

This doc shows how to:

* Install **ingress-nginx** on **EKS** (AWS).
* Expose it via **AWS NLB** (internet-facing or internal).
* Point app Helm charts to nginx via `ingress.className: nginx`.
* Automate subdomains with **ExternalDNS + Cloudflare**.
* Use **cert-manager** for TLS (HTTP-01 **or** DNS-01 via Cloudflare).
* Coexist with Traefik during migration.
* Validate, troubleshoot, and roll back safely.

---

## Prerequisites

* EKS cluster + `kubectl` + `helm` v3.
* (Recommended) **AWS Load Balancer Controller** installed and IAM permissions ready.
* DNS (Cloudflare/Route53) and (optional) **cert-manager** for ACME.

---

## 1) Install ingress-nginx (Helm)

Create a dedicated namespace and install the official chart.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClass=nginx \
  --set controller.watchIngressWithoutClass=false \
  --set controller.allowSnippetAnnotations=true \
  --set controller.metrics.enabled=true
```

> `controller.ingressClass=nginx` ensures the controller only processes Ingress objects with `ingressClassName: nginx`.

### 1.1) Expose with **AWS NLB**

Use Service annotations to select NLB scheme and target type. (Requires AWS Load Balancer Controller.)

**Internet-facing NLB, IP targets:**

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=external \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=ip
```

**Internal NLB:** set `aws-load-balancer-scheme=internal` instead.
**Dual-stack:** add `aws-load-balancer-ip-address-type=dualstack`.

> Changing NLB type on an existing Service may require recreating the Service.

### 1.2) Optional hardening

* Set `controller.config` (nginx config map) for security headers, timeouts, buffer sizes.
* Restrict access to the default backend and controller metrics.

---

## 2) Point your app Helm chart at **nginx**

Update your chart `values.yaml`:

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations: {}
  hosts:
    - host: ${ {values.app_name} }-${ {values.app_env} }.test.com
      paths:
        - path: /
          pathType: Prefix
  tls: []
```

**Probes & ports:** name the container port `http` if your probes use `port: http`.

---

## 2.5) ExternalDNS (Cloudflare) for auto-subdomains

Use ExternalDNS so hostnames from your `Ingress` objects are created/updated in Cloudflare automatically.

**Create a Cloudflare API token (least privilege):**

* Zone:DNS — **Edit**
* Zone:Zone — **Read**
* Scope: restrict to specific zones (recommended)

**Store the token:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: external-dns
type: Opaque
stringData:
  api-token: "<CF_API_TOKEN>"
```

**Deploy ExternalDNS (example manifest):**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: external-dns
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: external-dns
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: external-dns
spec:
  replicas: 1
  selector:
    matchLabels: { app: external-dns }
  template:
    metadata:
      labels: { app: external-dns }
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: ghcr.io/kubernetes-sigs/external-dns/external-dns:v0.14.2
        args:
          - --provider=cloudflare
          - --domain-filter=example.com         # replace with your zone
          - --policy=upsert-only
          - --registry=txt
          - --txt-owner-id=eks-nms              # any stable identifier
          - --sources=ingress
          - --log-format=json
        env:
          - name: CF_API_TOKEN
            valueFrom:
              secretKeyRef:
                name: cloudflare-api-token
                key: api-token
```

**Optional: orange-cloud proxy (per Ingress):**

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
```

> Tip: With `--sources=ingress`, ensure the Ingress `status.loadBalancer` is populated so ExternalDNS can publish the correct target (ALB/NLB). The AWS LB Controller with `controller.service.type=LoadBalancer` handles this.

---

## 3) TLS via **cert-manager** (recommended)

**HTTP-01 (simple)** — works if domain is *not* orange-proxied during issuance:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ops@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: acme-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

Annotate your app Ingress:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts: [ your.host.name ]
      secretName: your-host-tls
```

**DNS-01 (Cloudflare) — recommended if using orange-cloud proxy or want zero HTTP challenge traffic:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: "<CF_API_TOKEN>"
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns01
spec:
  acme:
    email: ops@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: acme-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```

Then, on your app Ingress:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-dns01
spec:
  tls:
    - hosts: [ your.host.name ]
      secretName: your-host-tls
```

---

## 4) Coexist with Traefik

* Keep both controllers if you’re migrating gradually.
* Use `ingress.className: nginx` for nginx, `traefik` for Traefik.
* Avoid setting a **default** IngressClass until the migration is complete.

---

## 5) Validation & Smoke Tests

1. **Check controller is up**

   ```bash
   kubectl -n ingress-nginx get deploy,svc,pods
   ```
2. **Get EXTERNAL-IP** for Service `ingress-nginx-controller`.
3. **DNS**: point hostnames to the NLB address (or rely on ExternalDNS).
4. **HTTP(S) check**

   ```bash
   curl -Ik https://app-dev.test.com/
   ```
5. **Status**: verify Ingress status fields are set (helps ExternalDNS).

---

## 6) Observability

* Enable metrics: `controller.metrics.enabled=true` and scrape with Prometheus.
* Expose metrics securely (ServiceMonitor/PodMonitor) and build Grafana dashboards.
* Inspect controller logs for 4xx/5xx spikes and upstream issues.

---

## 7) Common tweaks (ConfigMap `ingress-nginx-controller`)

Examples you can set via `--set controller.config.<key>=<val>`:

```yaml
client-body-buffer-size: 8k
proxy-read-timeout: "120"
proxy-send-timeout: "120"
hide-headers: Server
ssl-protocols: TLSv1.2 TLSv1.3
hsts: "true"
```

---

## 8) Troubleshooting

* **404**: wrong host/path in Ingress or Service `port/targetPort` mismatch.
* **Ingress ignored**: missing `ingressClassName: nginx` or controller not watching classes.
* **No EXTERNAL-IP**: check AWS LB Controller logs, subnet tags, and Service annotations.
* **TLS fails**: ensure cert-manager solver matches (`class: nginx` for HTTP-01, or DNS-01 token is valid).
* **Performance issues**: tune worker processes, buffers, keep-alives.

---

## 9) Rollback strategy

* Revert app `ingress.className` back to previous controller and redeploy.
* `helm rollback ingress-nginx <REVISION>` if controller upgrade caused regressions.

---

## Appendix: Notes specific to NMS

* Keep a **standard Ingress template** for all apps to reduce drift.
* Prefer **cert-manager** across controllers.
* Use **ExternalDNS** with stable Ingress status (or point A/ALIAS records directly to the NLB).
* Document which apps use nginx vs Traefik and the migration plan per app.

---

**End of doc**
