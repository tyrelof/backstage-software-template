from fastapi import APIRouter

router = APIRouter(tags=["Status"])


@router.get("/api/v1/status")
async def status():
    return {"status": "running", "app": "${{ values.app_name }}", "version": "1.0.0"}
