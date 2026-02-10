# API Documentation

## Overview

This FastAPI application provides a RESTful API with automatic interactive documentation.

## Interactive Documentation

FastAPI automatically generates interactive API documentation:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI Schema**: http://localhost:8000/openapi.json

## API Endpoints

### Root Endpoint

```
GET /
```

Returns welcome message and links to documentation.

**Response:**
```json
{
  "message": "Welcome to ${{ values.app_name }}",
  "docs": "/docs",
  "health": "/health"
}
```

### Status Endpoint

```
GET /api/v1/status
```

Returns application status.

**Response:**
```json
{
  "status": "running",
  "app": "${{ values.app_name }}",
  "version": "1.0.0"
}
```

## Adding New Endpoints

Create new endpoints in `src/app/routers/`:

1. Create a new router file, e.g., `src/app/routers/items.py`:

```python
from fastapi import APIRouter

router = APIRouter(prefix="/api/v1", tags=["items"])

@router.get("/items/{item_id}")
async def get_item(item_id: int):
    return {"item_id": item_id}
```

2. Register the router in `src/main.py`:

```python
from app.routers import items

app.include_router(items.router)
```

## Request/Response Models

Use Pydantic models for request/response validation:

```python
from pydantic import BaseModel

class Item(BaseModel):
    name: str
    description: str | None = None
    price: float

@app.post("/items/")
async def create_item(item: Item):
    return item
```
