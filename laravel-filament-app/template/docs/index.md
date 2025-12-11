# ${{ values.app_name }}

Welcome to **${{ values.app_name }}**, a Laravel + Filament service generated through Backstage.

## 🚀 Overview

Your service includes:

- Laravel 12.x  
- Filament 3.x  
- Horizon (optional)  
- Reverb (optional)  
- Queue workers (configurable)  
- Nginx + PHP-FPM base image  
- Kubernetes-ready Helm chart  

## 📦 Deployment

Your service includes a full Helm chart at:

```
charts/${{ values.app_name }}/
```

To deploy:

```bash
helm upgrade --install \
  ${{ values.app_name }} \
  charts/${{ values.app_name }} \
  -f charts/${{ values.app_name }}/values.yaml
```

## ⚙️ Configuration

Configuration is managed in:

```
charts/${{ values.app_name }}/values.yaml
```

Here you can enable:

- workers  
- reverb  
- cron  
- ingress
- service ports
- replicas  
- autoscaling  
- resources
- node selectors  

## 🛠 Local Development

```bash
git clone https://${{ parameters.gitlabHost }}/${{ parameters.ownerPath }}/${{ values.app_name }}.git
```
Install dependencies:
```bash
composer install
npm install
npm run dev
php artisan serve
```
Run Laravel locally:
```bash
php artisan serve
```

## 📚 TechDocs
This documentation is built using Backstage TechDocs and MkDocs.

To build locally:

```bash
npx @techdocs/cli generate
```

To preview:

```bash
npx @techdocs/cli serve
```
