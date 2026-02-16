FROM python:3.11-slim

WORKDIR /app

# Install dependencies first for caching
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
  && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir -r requirements.txt

# Create user before copying code
RUN useradd -m -u 1000 appuser

# Copy code and set ownership
COPY --chown=appuser:appuser app /app/app
COPY --chown=appuser:appuser tests /app/tests

USER appuser

# Default port (override in k8s via env PORT)
ENV PORT=8000

# EXPOSE cannot be dynamic
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT}/health" || exit 1

# Use sh -c so $PORT expands
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
