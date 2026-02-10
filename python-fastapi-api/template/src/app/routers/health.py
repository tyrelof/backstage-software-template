from fastapi import APIRouter

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health():
    return {"status": "healthy", "app": "${{ values.app_name }}"}


@router.get("/ready")
async def readiness():
    return {"status": "ready", "app": "${{ values.app_name }}"}
