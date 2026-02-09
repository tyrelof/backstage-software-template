# GITLAB_CI.md

This document explains the CI/CD behavior for this repository.

It is written to help quickly understand *why* the pipeline is structured this way.

---

## Goals

- Build and deploy automatically from `main`
- **Only rebuild images** when code or Dockerfile changes
- **Allow chart-only changes** to deploy without rebuilding
- Support **fast rollback** by pinning known-good image tags
- Stay close to **KISS** while avoiding unnecessary rebuilds

---

## Pipeline overview

### Stages

1. **lint**
   - Validate `.gitlab-ci.yml` formatting

2. **prep**
   - Ensure ECR repository exists

3. **build**
   - Build and push image using BuildKit + registry cache
   - Runs **only** when image inputs change

4. **release**
   - Split into two deploy paths:
     - Image-based deploy
     - Chart-only deploy
   - Production deploys are manual

---

## The two CD paths (1-page mental diagram)

```
                ┌──────────────┐
                │  main branch │
                └──────┬───────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐          ┌─────────▼─────────┐
│ src/ or Docker │          │ charts/** only     │
│ changed        │          │ changed            │
└───────┬────────┘          └─────────┬─────────┘
        │                             │
┌───────▼────────┐          ┌─────────▼─────────┐
│ Build image     │          │ No image build    │
│ (BuildKit)     │          │                   │
└───────┬────────┘          └─────────┬─────────┘
        │                             │
┌───────▼────────┐          ┌─────────▼─────────┐
│ Bump values     │          │ Keep image tag    │
│ image tag      │          │ unchanged         │
└───────┬────────┘          └─────────┬─────────┘
        │                             │
┌───────▼────────┐          ┌─────────▼─────────┐
│ ArgoCD sync     │          │ ArgoCD sync       │
│ (stage)        │          │ (stage)           │
└───────┬────────┘          └─────────┬─────────┘
        │                             │
        └─────────────┬───────────────┘
                      ▼
              Manual prod deploy
```

---

## Trigger rules (mental model)

### Pipeline creation
A pipeline is created only when:
- branch is `main`, AND
- any of these changed:
  - `src/**`
  - `Dockerfile`
  - `charts/**`
  - `.gitlab-ci.yml`

### Job behavior

- **Image path**
  - Triggered by `src/**` or `Dockerfile`
  - Builds image
  - Updates values image tag
  - Syncs via ArgoCD

- **Chart path**
  - Triggered by `charts/**`
  - Does *not* rebuild image
  - Does *not* change image tag
  - Syncs chart changes only

---

## Typical scenarios

### Chart-only change
Examples:
- Ingress annotations
- Resources / limits
- Feature flags

Result:
- No image build
- Fast deploy

### Code or Dockerfile change
Examples:
- App logic change
- Dependency update

Result:
- Image rebuild
- Values image tag bumped
- Deploy

### Rollback

- Edit values file
- Pin known-good image tag
- Commit
- Chart-only deploy path syncs

---

## When NOT to use split CD (important)

This setup is **not required** when:

- The service is experimental or throwaway
- Build time is already very fast
- You rarely deploy chart-only changes
- The team is small and prefers brute-force simplicity

In those cases:
- A single build + deploy job is perfectly fine
- Rebuilding images on every change is acceptable

Split CD is justified **only because**:
- BuildKit caching is already in place
- Image builds are non-trivial
- Rollback speed matters

---

## Final note

This pipeline is optimized for **clarity + safety**, not cleverness.

If it ever feels confusing again:
- Remove the chart-only path
- Go back to a single deploy job

Nothing here is irreversible.

