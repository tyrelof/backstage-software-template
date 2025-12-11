# (Frontend – devs build assets locally and commit)

# =====================================
# 1) Composer build stage (vendor deps)
# =====================================
FROM composer:2.5.0 AS vendor

WORKDIR /app

COPY ./src/composer.json ./src/composer.lock ./

RUN mkdir -p database/seeders database/factories

ARG COMPOSER_AUTH_JSON
ENV COMPOSER_AUTH="$COMPOSER_AUTH_JSON"

RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-scripts \
    --prefer-dist

# ============================
# 2) Final runtime image
# ============================
FROM public.ecr.aws/h1y8m9v5/popapps-php8.3.24-fpm-base:latest

WORKDIR /var/www/html

# =======================================
# App-specific dependencies
#
# 1) PHP extensions ONLY
#    Use this when the app truly needs extra PHP extensions.
#    Example:
#    RUN install-php-extensions gd intl redis
#
# 2) System packages (RARE, app-specific)
#    Only for libs like ffmpeg, ImageMagick, etc. that not all apps need.
#    Coordinate with DevOps before adding here.
#    Example:
#    RUN set -eux; \
#        apt-get update; \
#        apt-get install -y --no-install-recommends ffmpeg; \
#        rm -rf /var/lib/apt/lists/*
#
# ❌ Do NOT install random tools (git, vim, curl, etc.) here.
#    Those belong in the base image if truly needed by everyone.
# =======================================

# Copy application source
COPY --chown=www-data:www-data ./src .

# Copy vendor from build stage
COPY --from=vendor /app/vendor ./vendor

# Optional Nginx overrides (dir kept by .gitkeep; may be empty)
COPY nginx/snippets/ /etc/nginx/conf.d/

# Laravel permissions
RUN mkdir -p storage bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R 775 storage bootstrap/cache
