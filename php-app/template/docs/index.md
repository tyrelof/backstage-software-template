# ${{ values.name }}


${{ values.description | default('A PHP service scaffolded by Backstage.') }}


## Quickstart


### Requirements
- PHP ${{ values.phpVersion }}
- Composer 2.x
- (Optional) Docker & Docker Compose


### Local
```bash
composer install
php -S 0.0.0.0:8080 -t public

Open http://localhost:8080

Docker

docker compose up --build