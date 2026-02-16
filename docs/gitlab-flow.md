# GitLab + Backstage Flow (Current)

This repository contains Backstage software templates that scaffold service repositories with GitLab publishing and Backstage registration.

## What the templates do

Most templates in this repo use the same flow in `template.yaml`:

1. `fetch:template` — renders files from the template skeleton
2. `publish:gitlab` — creates and pushes a new GitLab repository
3. `catalog:register` — registers generated `catalog-info.yaml` in Backstage

## CI/CD responsibility split

- **This template repo**: provides boilerplate CI/CD files (`.gitlab-ci.yml`, charts, deployment structure) inside each template's `template/` folder.
- **Generated service repo**: owns and runs the actual pipeline jobs after scaffolding.
- **Platform/cluster setup**: IRSA, runner permissions, ECR access, and Argo CD are infrastructure concerns documented separately.

## Where to configure pipeline behavior

After creating a service from Backstage, manage runtime CI/CD details in the generated service repository:

- `.gitlab-ci.yml`
- `charts/<service>/values-*.yaml`
- environment and protected project/group variables in GitLab

## Notes

- Keep this document implementation-agnostic at repo level.
- Do not copy long, environment-specific pipeline recipes here; place those in service repos or platform runbooks.
