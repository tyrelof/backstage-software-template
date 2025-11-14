# --- Composer Builder (Backend) ---
FROM composer:2.5.0 AS vendor
WORKDIR /app

# Copy composer files from template's src/
COPY ./src/composer.json ./src/composer.lock ./

# Create dirs some packages expect
RUN mkdir -p database/seeders database/factories

# Install PHP deps (no scripts yet)
# IMPORTANT: token should come from CI env, not hardcoded
ARG COMPOSER_AUTH_JSON
ENV COMPOSER_AUTH="$COMPOSER_AUTH_JSON"

RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-scripts \
    --prefer-dist

# --- Final App Image ---
FROM public.ecr.aws/h1y8m9v5/nmsai-php8.3.24-fpm-base:latest

WORKDIR /var/www/html

# Copy application source code
COPY --chown=www-data:www-data ./src .

# Copy PHP dependencies
COPY --from=vendor /app/vendor ./vendor

# (Frontend commented out on purpose – devs build assets locally and commit)
# COPY --from=frontend /app/public/build ./public/build

# Copy any app-specific s6 services (if needed)
COPY ./s6-services /etc/services.d/
RUN chmod -f +x /etc/services.d/*/run || true

# Permissions
RUN mkdir -p storage bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R 775 storage bootstrap/cache


#  # -----------------------------
# # Stage 1: Composer dependencies
# # -----------------------------
# FROM composer:2.5 AS vendor

# WORKDIR /app

# # Copy composer files from the template's Laravel src
# COPY ./src/composer.json ./src/composer.lock* ./

# # If you need private GitLab/Nexus auth, pass via CI as COMPOSER_AUTH
# # Example in GitLab:
# #   COMPOSER_AUTH='{"gitlab-token": {"nexus.nmscreative.com": "glpat-xxxxx"}}'
# ARG COMPOSER_AUTH
# ENV COMPOSER_AUTH=${COMPOSER_AUTH}

# # Install PHP dependencies (no scripts yet)
# RUN composer install \
#     --ignore-platform-reqs \
#     --no-interaction \
#     --no-scripts \
#     --prefer-dist

# # -----------------------------
# # Stage 2: Final app image
# # -----------------------------
# FROM public.ecr.aws/h1y8m9v5/nmsai-php8.3.24-fpm-base:latest

# WORKDIR /var/www/html

# # Copy application source code
# COPY --chown=www-data:www-data ./src .

# # Copy vendor from build stage
# COPY --from=vendor /app/vendor ./vendor

# # Ensure Laravel storage/cache are writable
# RUN mkdir -p storage bootstrap/cache \
#  && chown -R www-data:www-data storage bootstrap/cache \
#  && chmod -R 775 storage bootstrap/cache

# # Base image already:
# # - runs s6
# # - manages nginx + php-fpm
# # - exposes the correct port (80 in your base)
# #
# # So we don't override ENTRYPOINT/CMD here.
