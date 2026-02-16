import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.routers import health, status

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Application startup: ${{ values.app_name }}")
    yield
    logger.info("Application shutdown: ${{ values.app_name }}")


app = FastAPI(
    title="${{ values.app_name }}",
    description="FastAPI service: ${{ values.app_name }}",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(health.router)
app.include_router(status.router)


@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Welcome to ${{ values.app_name }}",
        "docs": "/docs",
        "health": "/health",
    }
