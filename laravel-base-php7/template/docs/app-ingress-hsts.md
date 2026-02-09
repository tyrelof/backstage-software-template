# HSTS control (per-app) — Ingress-NGINX + cert-manager

This note is meant to live **inside an application repo** (owned by devs) so teams can control **HSTS on their own Ingress** without needing access to the platform/ingress-nginx controller.

> **Default recommendation (for new EKS rollouts):** keep HSTS **OFF** per-app until DNS + TLS + redirects are proven stable, then enable it intentionally.

---

## Why you care

**HSTS (Strict-Transport-Security)** tells browsers to force HTTPS for a period of time.  
If you enable it too early and later have TLS/DNS/redirect issues, users may get “stuck” with HTTPS-only behavior until the HSTS timer expires.

---

## Where to configure it (dev-owned)

With Ingress-NGINX, HSTS can be controlled **per Ingress** using annotations.

### Disable HSTS (recommended while onboarding / testing)

Add these annotations to your app Ingress:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/hsts: "false"
```

If you also want to be explicit about redirect behavior:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"   # typical
    nginx.ingress.kubernetes.io/hsts: "false"
```

> Turning off HSTS does **not** turn off HTTPS — it only stops sending the HSTS header.

---

## Enable HSTS (when you’re confident)

When you are ready to lock it down:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"          # 1 year
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"   # optional
    nginx.ingress.kubernetes.io/hsts-preload: "false"             # keep false unless you REALLY mean it
```

### Suggested rollout strategy
1. Start with **small max-age** (e.g., 300 or 3600 seconds)
2. Observe for a day/week
3. Increase to 1 week → 1 month → 1 year

Example “safe-ish first step”:

```yaml
nginx.ingress.kubernetes.io/hsts: "true"
nginx.ingress.kubernetes.io/hsts-max-age: "3600"
nginx.ingress.kubernetes.io/hsts-include-subdomains: "false"
nginx.ingress.kubernetes.io/hsts-preload: "false"
```

---

## Helm values example (values-stage.yaml / values-prod.yaml)

If your chart supports something like `.Values.ingress.annotations`, this is the cleanest dev-controlled way:

```yaml
ingress:
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: le-staging
    nginx.ingress.kubernetes.io/hsts: "false"
  hosts:
    - host: app.stage.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-tls
      hosts:
        - app.stage.example.com
```

Then devs can flip HSTS by PR/commit without touching the cluster-level ingress controller.

---

## Important note if you use Cloudflare

Cloudflare can also inject/force HSTS depending on zone/edge settings.

If you see HSTS headers but your Ingress annotations say `hsts: "false"`:
- check Cloudflare’s security headers / HSTS settings for the zone
- confirm which layer is actually adding the header by inspecting response headers:
  - browser devtools Network tab
  - `curl -I https://your-host` and look for `strict-transport-security`

---

## “When NOT to enable HSTS yet”

Hold off if any of these are still changing:
- cert-manager issuer, DNS validation, or TLS secrets are still in flux
- you’re still switching between staging/prod issuers frequently
- you’re still debugging redirects (HTTP→HTTPS loops, Cloudflare proxying, etc.)
- this is your first production migration to EKS and you want low-risk rollback paths

---

## Quick sanity checks

- Confirm HTTPS works:
  - `curl -I https://HOST`
- Confirm whether HSTS is being sent:
  - look for: `strict-transport-security: ...`
- Confirm who is adding it:
  - Ingress-NGINX vs Cloudflare vs app

---

### TL;DR
- Devs control HSTS **per Ingress** with annotations.
- Start **OFF**, enable later with a **small max-age** first.
- Be careful with **preload** and **includeSubDomains**.
