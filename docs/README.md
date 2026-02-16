# Repository Docs Scope

This top-level `docs/` directory only keeps repository-level notes for maintaining Backstage templates.

## Kept here

- `php-templates.md` — PHP template notes for this repository
- `gitlab-flow.md` — high-level GitLab + Backstage flow

## Not kept here

Environment-specific operational runbooks (IRSA, ingress operations, local cluster setup) should live in:

- platform/infrastructure repositories, or
- generated service repositories (`template/docs` in each template)
