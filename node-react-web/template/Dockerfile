# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app
RUN apk update && apk upgrade --no-cache && npm install -g npm@latest
COPY package.json package-lock.json* ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Serve
FROM nginx:alpine

RUN apk update && apk upgrade --no-cache

# Ensure runtime dirs are writable when running as non-root (e.g., K8s runAsNonRoot)
RUN mkdir -p /var/cache/nginx/client_temp /var/run /var/log/nginx \
	&& chmod -R 777 /var/cache/nginx /var/run /var/log/nginx

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
