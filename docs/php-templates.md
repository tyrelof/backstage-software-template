# Backstage PHP Templates in This Repository

This page describes the PHP/Laravel templates that are actually maintained in this repository.

## Available PHP templates

- `laravel-base-php7` — Laravel legacy baseline (PHP 7.3)
- `laravel-base-php8` — Laravel baseline (PHP 8.2)
- `laravel-filament-php8` — Laravel + Filament admin panel (PHP 8)

Each template is defined by:

- `<template>/template.yaml` for scaffolder inputs and steps
- `<template>/template/` for generated project files

## Backstage flow used by these templates

The PHP templates follow the same standard flow as the other stacks in this repo:

1. `fetch:template`
2. `publish:gitlab`
3. `catalog:register`

## How to expose templates in Backstage

Templates are discovered from `catalog-info.yaml` at repo root under `spec.targets`.

Example entry:

```yaml
- ./laravel-base-php8/template.yaml
```

## Scope note

This doc intentionally avoids generic, standalone template blueprints.
Use the actual files under each template directory as the source of truth.
