from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    app: str


class ErrorResponse(BaseModel):
    detail: str
    status_code: int
