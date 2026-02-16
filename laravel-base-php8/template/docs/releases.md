# RELEASES.md

This file tracks **known-good releases** for this application.

Its primary purpose is to support **fast, low-risk rollback** without rebuilding images.

---

## How to use this file

- Every time a release is considered **stable**, record it here.
- Use the image tag listed here when rolling back via Helm values.
- This file is **human-maintained**, not automated.

---

## Release log

### YYYY-MM-DD — Stable
- **Image tag:** `<commit-sha>`
- **Environment:** stage / prod
- **Reason:** Initial stable release
- **Notes:**
  - Deployed via image CD path
  - Verified manually

---

### YYYY-MM-DD — Stable
- **Image tag:** `<commit-sha>`
- **Environment:** prod
- **Reason:** Hotfix / rollback target
- **Notes:**
  - Used for rollback reference

---

## Rollback procedure (GitOps)

1. Open the appropriate values file:
   - `charts/<app>/values-stage.yaml`
   - `charts/<app>/values-prod.yaml`

2. Set the image tag to a known-good value:

```yaml
image:
  repository: <ecr-repo>
  tag: <known-good-tag>
```

3. Commit and push.
4. ArgoCD syncs the change.
5. Pods roll back to the pinned image.

No image rebuild is required.

---

## Notes

- Always prefer **commit-SHA tags**, not `latest`.
- This file is the authoritative rollback reference.

