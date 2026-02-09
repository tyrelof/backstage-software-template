from fastapi import FastAPI
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="${{ values.app_name }}",
    description="FastAPI service: ${{ values.app_name }}",
    version="1.0.0",
)


@app.on_event("startup")
async def startup_event():
    """Run on application startup"""
    logger.info("Application startup: ${{ values.app_name }}")


@app.on_event("shutdown")
async def shutdown_event():
    """Run on application shutdown"""
    logger.info("Application shutdown: ${{ values.app_name }}")


@app.get("/health", tags=["Health"])
async def health():
    """Health check endpoint - used for liveness probes"""
    return {
        "status": "healthy",
        "app": "${{ values.app_name }}",
    }


@app.get("/ready", tags=["Health"])
async def readiness():
    """Readiness check endpoint - used for readiness probes"""
    return {
        "status": "ready",
        "app": "${{ values.app_name }}",
    }


@app.get("/api/v1/status", tags=["Status"])
async def status():
    """Application status endpoint"""
    return {
        "status": "running",
        "app": "${{ values.app_name }}",
        "version": "1.0.0",
    }


@app.get("/", tags=["Root"])
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to ${{ values.app_name }}",
        "docs": "/docs",
        "health": "/health",
    }
