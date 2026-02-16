# syntax=docker/dockerfile:1.5

# Stage 1: Builder
FROM node:20-alpine AS builder

WORKDIR /app

RUN apk update && apk upgrade --no-cache

RUN npm install -g npm@latest

COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY . .

# Stage 2: Production
FROM node:20-alpine

WORKDIR /app

RUN apk update && apk upgrade --no-cache

RUN npm install -g npm@latest

ENV NODE_ENV=production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=builder /app/package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

COPY --from=builder /app/src ./src

USER nodejs

EXPOSE 3000

CMD ["node", "src/server.js"]
