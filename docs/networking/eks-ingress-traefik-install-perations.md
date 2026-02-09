---

title: Traefik Ingress on EKS: Install & Operations (Playbook)
slug: eks-ingress-traefik-install-operations
last_updated: 2025-10-09
version: v1.0
owners: [platform, devops]
status: stable
tags: [eks, ingress, traefik, nlb, tls, cert-manager, externaldns, cloudflare]
------------------------------------------------------------------------------

# Traefik Ingress on EKS: Install & Operations (Playbook)

**Last updated:** 2025‑10‑09 (Asia/Manila)

## Scope

This doc shows how to:

* Install Traefik as a Kubernetes Ingress controller on **EKS**.
* Run Traefik **alongside** ingress‑nginx.
* Point your app Helm charts to Traefik via `ingress.className`.
* Automate subdomains with **ExternalDNS + Cloudflare**.
* Use either **cert‑manager** or **Traefik ACME** for TLS.
* (Optional) Expose Traefik via **AWS NLB** with the AWS Load Balancer Controller.
* Validate traffic flow and roll back if needed.

---

## Prerequisites

* EKS cluster, `kubectl`, and `helm` v3.
* (Recommended) **AWS Load Balancer Controller** installed for NLB provisioning.
* DNS (e.g., Cloudflare/Route53) + (optional) **cert‑manager** if using ACME via cert‑manager.

---

## 1) Install Traefik (Helm)

Create a dedicated namespace and install Traefik. This creates a `Service` of type `LoadBalancer` by default.

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Simple install (internet-facing LB via default settings)
helm install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set providers.kubernetesIngress.enabled=true \
  --set providers.kubernetesIngress.ingressClass=traefik \
  --set providers.kubernetesIngress.publishedService.enabled=true \
  --set ingressRoute.dashboard=true \
  --set service.type=LoadBalancer
```

> **Note:** `providers.kubernetesIngress.ingressClass=traefik` scopes Traefik to only process Ingress objects that declare `ingressClassName: traefik`.

### 1.1) Expose Traefik with an AWS **NLB** (recommended on EKS)

If you’re using the **AWS Load Balancer Controller**, add these annotations to Traefik’s Service to make it an **NLB** and choose **IP targets**.

```bash
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --set providers.kubernetesIngress.enabled=true \
  --set providers.kubernetesIngress.ingressClass=traefik \
  --set providers.kubernetesIngress.publishedService.enabled=true \
  --set ingressRoute.dashboard=true \
  --set service.type=LoadBalancer \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=external \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=ip
```

**Variants:**

* **Internal** NLB → set `aws-load-balancer-scheme=internal`.
* **Dual‑stack** (IPv4 + IPv6) → add `aws-load-balancer-ip-address-type=dualstack`.
* **Name the LB** → add `aws-load-balancer-name=<friendly-name>`.

> **Heads‑up:** Do **not** edit NLB type annotations on an existing Service; if you must change them, recreate the Service.

### 1.2) Optional: secure Traefik dashboard

Traefik’s chart can publish the dashboard via an `IngressRoute`. Protect it with basic auth in production.

```bash
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --set ingressRoute.dashboard=true \
  --set api.dashboard=true
```

For stricter security, add a BasicAuth middleware (CRD) and reference it from the dashboard `IngressRoute`. Keep the dashboard internal when possible.

---

## 2) Point your app Helm chart at **Traefik**

Switch your chart’s `values.yaml` from nginx to Traefik by changing the ingress class and (optionally) adding Traefik annotations.

**Before (nginx):**

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

**After (Traefik):**

```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "web,websecure"
    # Enable HTTPS routing if you have TLS (secret or cert‑manager):
    # traefik.ingress.kubernetes.io/router.tls: "true"
  hosts:
    - host: ${ {values.app_name} }-${ {values.app_env} }.test.com
      paths:
        - path: /
          pathType: Prefix
  tls: []
```

**Probes & ports:** If you reference `port: http` in your probes, ensure the container port is **named** `http` in your Deployment:

```yaml
ports:
  - name: http
    containerPort: 5000
```

---

## 2.5) ExternalDNS (Cloudflare) for auto‑subdomains

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

**Optional: orange‑cloud proxy (per Ingress):**

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
```

> **Tip:** With `--sources=ingress`, ensure the Ingress `status.loadBalancer` is populated so ExternalDNS can publish the correct target (ALB/NLB). Traefik chart flag `providers.kubernetesIngress.publishedService.enabled=true` helps set this automatically.

---

## 3) Coexist with nginx safely

You can run **ingress‑nginx** and **Traefik** at the same time.

* Use `ingress.className: nginx` for nginx‑routed apps.
* Use `ingress.className: traefik` for Traefik‑routed apps.
* Don’t mark either IngressClass as **default** until you’re done migrating.

> To make a controller the cluster default later, set `metadata.annotations["ingressclass.kubernetes.io/is-default-class"]="true"` on its `IngressClass` resource.

---

## 4) TLS options

### 4.1) **cert‑manager** (recommended)

Keep certificates consistent across controllers. Example for Let’s Encrypt (HTTP‑01) cluster issuer:

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
            class: traefik
```

Then in your app’s Ingress:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts: [ your.host.name ]
      secretName: your-host-tls
```

**DNS‑01 (Cloudflare) with cert‑manager** — recommended if using orange‑cloud proxy or you want to avoid HTTP challenges:

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

### 4.2) Traefik ACME (built‑in)

If you prefer Traefik to fetch certificates, configure a certificate resolver in Traefik’s Helm values and add annotations to your Ingress. **Use one approach—either cert‑manager or Traefik ACME—per hostname.**

**Helm values snippet (DNS‑01 via Cloudflare, recommended if orange‑proxying):**

```yaml
# values.yaml (snippets)
additionalArguments:
  - "--certificatesresolvers.le.acme.email=ops@example.com"
  - "--certificatesresolvers.le.acme.storage=/data/acme.json"
  - "--certificatesresolvers.le.acme.dnschallenge.provider=cloudflare"
  # Optional: tweak propagation
  # - "--certificatesresolvers.le.acme.dnschallenge.delayBeforeCheck=0"

env:
  - name: CF_DNS_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: api-token

persistence:
  enabled: true
  path: /data
```

**On the app Ingress:**

```yaml
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: "le"
```

**Notes:**

* **HTTP‑01** with Traefik also works if your LB exposes port **80** and the domain isn’t orange‑proxied in Cloudflare.
* Persist `acme.json` so certs survive pod restarts (done above via `persistence`).

---

## 5) Useful Traefik middlewares (CRDs)

Create once, then reference via annotations on your Ingress.

**Force HTTPS redirect**

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
  namespace: default
spec:
  redirectScheme:
    scheme: https
    permanent: true
```

Use on an Ingress:

```yaml
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: "default-redirect-https@kubernetescrd"
```

**Harden headers (HSTS, X-Frame-Options, etc.)**

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: secure-headers
  namespace: default
spec:
  headers:
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
    frameDeny: true
    contentTypeNosniff: true
```

**IP allowlist**

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: office-allowlist
  namespace: default
spec:
  ipAllowList:
    sourceRange:
      - 203.0.113.0/24  # replace
```

Reference multiple middlewares with a comma‑separated list in `router.middlewares`.

---

## 6) Validation & Smoke Tests

1. **Check Traefik is up**

   ```bash
   kubectl -n traefik get deploy,svc,pods
   ```
2. **Confirm external address**

   ```bash
   kubectl -n traefik get svc traefik -o wide
   ```
3. **DNS**: point your host (e.g., `app-dev.test.com`) to the Traefik Service EXTERNAL‑IP (or rely on ExternalDNS).
4. **Ingress status propagation**: `providers.kubernetesIngress.publishedService.enabled=true` (or set `ingressEndpoint.publishedService: "traefik/traefik"`).
5. **HTTP checks**

   ```bash
   curl -Ik https://app-dev.test.com/
   ```

---

## 7) Migration & Rollback

**Canary move** a non‑critical app first:

1. Install Traefik.
2. Change that app’s chart to `ingress.className: traefik` and deploy.
3. Verify routes, logs, TLS, and dashboards.
4. Migrate services one‑by‑one.
5. (Optional) Set Traefik’s IngressClass as **default**.
6. Decommission ingress‑nginx when all traffic is moved.

**Rollback:**

* Revert the app’s `ingress.className` back to `nginx` and redeploy.
* If needed, `helm rollback` the Traefik release (Traefik removal will drop its LB and dashboard).

---

## 8) Troubleshooting

* **404 from Traefik** → Ingress missing `ingress.className: traefik`, wrong host/path, or Service port name/number mismatch.
* **Ingress not picked up** → Traefik’s `providers.kubernetesIngress.ingressClass` does not match your Ingress className.
* **Health checks failing on NLB** → verify target type (`ip` vs `instance`), health‑check protocol/path/port annotations, security group rules to Pods/ENIs.
* **No EXTERNAL‑IP** → check AWS Load Balancer Controller logs, Service annotations, and subnet tags for LB discovery.
* **Probes failing** → ensure the container port is **named** `http` if probes reference `port: http`.

---

## 9) Example: App `values.yaml` (Traefik‑ready)

```yaml
replicaCount: 1
image:
  repository: tyrelfecha/${{values.app_name}}
  pullPolicy: IfNotPresent
  tag: tyrelfecha/${{values.app_name}}-${{values.app_env}}-latest
imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""
serviceAccount:
  create: true
  automount: true
  annotations: {eks.amazonaws.com/role-arn: arn:aws:iam::567540846696:role/<ECRPushRole>}
  name: "gitlab-job-sa"
podAnnotations: {}
podLabels: {}
podSecurityContext: {}
securityContext: {}
service:
  type: ClusterIP
  port: 5000
ingress:
  enabled: true
  className: "traefik"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "web,websecure"
  hosts:
    - host: ${{values.app_name}}-${{values.app_env}}.test.com
      paths:
        - path: /
          pathType: Prefix
  tls: []
resources:
  requests:
    cpu: 50m
    memory: 50M
livenessProbe:
  httpGet:
    path: /api/v1/healthz
    port: http
readinessProbe:
  httpGet:
    path: /api/v1/healthz
    port: http
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
volumes: []
volumeMounts: []
nodeSelector: {}
tolerations: []
affinity: {}
```

> Ensure your Deployment’s container has a port named `http` mapped to `5000`.

---

## 10) Example: Traefik Service annotations for NLB

Attach to **internet‑facing** NLB with **IP** targets:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: traefik
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
spec:
  type: LoadBalancer
  ports:
    - name: web
      port: 80
      targetPort: web
    - name: websecure
      port: 443
      targetPort: websecure
  selector:
    app.kubernetes.io/name: traefik
```

**Internal NLB**: set `aws-load-balancer-scheme: internal`. For dual‑stack, add `aws-load-balancer-ip-address-type: dualstack`.

---

## Appendix: Notes specific to NMS

* Keep nginx around for legacy routes while migrating.
* Use **cert‑manager** for consistency across nginx & Traefik (or commit to Traefik ACME only).
* Standardize middlewares (HTTPS redirect, security headers) as CRDs in a shared namespace and reference from apps.
* For ExternalDNS, set Traefik provider’s `publishedService.enabled=true` (or `ingressEndpoint.publishedService: "traefik/traefik"`) if you need ingress status propagation.

---

**End of doc**
