# API Routes

This Python/FastAPI application provides REST API endpoints for data access and business logic. Routes are organized in `/app/routers/`.

---

## 🚀 Route Structure

```
app/
├── main.py                 # FastAPI app entry point
├── models.py              # Pydantic models (request/response)
├── routers/               # Route modules
│   ├── health.py         # Health endpoints
│   ├── status.py         # Status endpoints
│   └── users.py          # Users endpoints (example)
└── logger.py             # Logging configuration
```

---

## 📝 Request/Response Format

### Standard Response

```json
{
  "success": true,
  "data": { ... },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Error Response

```json
{
  "success": false,
  "error": "User not found",
  "code": "USER_NOT_FOUND",
  "status_code": 404,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 🔌 Core Endpoints

### Health Endpoints

```python
# app/routers/health.py
from fastapi import APIRouter
from datetime import datetime

router = APIRouter()

@router.get("/health", tags=["Health"])
async def health():
    """Liveness probe"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
    }

@router.get("/health/ready", tags=["Health"])
async def readiness():
    """Readiness probe"""
    # Check dependencies (DB, cache, etc.)
    return {
        "status": "ready",
        "dependencies": {
            "database": "connected",
            "cache": "connected",
        },
    }
```

**Usage**:
```bash
GET /health              # Liveness probe
GET /health/ready        # Readiness probe
```

---

## 👥 Users Endpoints (Example)

### Data Model

```python
# app/models.py
from pydantic import BaseModel, EmailStr
from typing import Optional

class UserBase(BaseModel):
    name: str
    email: EmailStr

class UserCreate(UserBase):
    pass

class User(UserBase):
    id: int
    created_at: str

    class Config:
        from_attributes = True
```

### List Users

```python
# app/routers/users.py
from fastapi import APIRouter, Depends
from app.models import User

router = APIRouter()

@router.get("/api/users", response_model=list[User], tags=["Users"])
async def list_users(skip: int = 0, limit: int = 10):
    """Get all users with pagination"""
    users = await get_users_from_db(skip=skip, limit=limit)
    return users
```

**Request**:
```bash
GET /api/users?skip=0&limit=20
```

**Response** (200):
```json
[
  {"id": 1, "name": "John", "email": "john@example.com", "created_at": "2024-01-01"},
  {"id": 2, "name": "Jane", "email": "jane@example.com", "created_at": "2024-01-02"}
]
```

### Get Single User

```python
@router.get("/api/users/{user_id}", response_model=User, tags=["Users"])
async def get_user(user_id: int):
    """Get a specific user by ID"""
    user = await fetch_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
            headers={"X-Error-Code": "USER_NOT_FOUND"},
        )
    return user
```

**Request**:
```bash
GET /api/users/1
```

**Response** (200):
```json
{
  "id": 1,
  "name": "John",
  "email": "john@example.com",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### Create User

```python
@router.post("/api/users", response_model=User, status_code=201, tags=["Users"])
async def create_user(user: UserCreate):
    """Create a new user"""
    new_user = await db.users.insert_one({
        "name": user.name,
        "email": user.email,
    })
    return new_user
```

**Request**:
```bash
POST /api/users
Content-Type: application/json

{
  "name": "Alice",
  "email": "alice@example.com"
}
```

**Response** (201):
```json
{
  "id": 3,
  "name": "Alice",
  "email": "alice@example.com",
  "created_at": "2024-01-03T00:00:00Z"
}
```

---

## 🔐 Authentication

All protected routes require Bearer token in `Authorization` header:

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8000/api/users
```

**Implementation**:
```python
# app/routers/auth.py
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthCredentials

security = HTTPBearer()

async def verify_token(credentials: HTTPAuthCredentials = Depends(security)):
    token = credentials.credentials
    # Verify token...
    if not is_valid_token(token):
        raise HTTPException(status_code=401, detail="Invalid token")
    return token

@router.get("/api/secure")
async def secure_endpoint(token: str = Depends(verify_token)):
    return {"message": "Authorized"}
```

---

## ✅ Input Validation

Uses Pydantic for automatic request validation:

```python
# app/models.py
from pydantic import BaseModel, Field, validator

class UserCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: str = Field(..., pattern=r'^[^@]+@[^@]+\.[^@]+$')
    age: int = Field(..., ge=0, le=150)
    
    @validator('name')
    def name_not_empty(cls, v):
        if not v.strip():
            raise ValueError('Name cannot be empty')
        return v.strip()
```

**Validation errors** automatically return 422:
```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "Invalid email format",
      "type": "value_error"
    }
  ]
}
```

---

## 🧪 Testing Endpoints

### Using curl

```bash
# Health check
curl http://localhost:8000/health

# List users (with auth)
curl -H "Authorization: Bearer <token>" \
  http://localhost:8000/api/users

# Create user
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"Bob","email":"bob@example.com"}' \
  http://localhost:8000/api/users
```

### Using FastAPI Docs

Navigate to:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## 🚨 Error Handling

FastAPI exception handling:

```python
# app/main.py
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

app = FastAPI()

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": "Internal server error",
            "code": "INTERNAL_ERROR",
        },
    )
```

**Common Errors**:
- `400` - Bad Request (validation failed)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (resource doesn't exist)
- `422` - Unprocessable Entity (validation error)
- `500` - Internal Server Error

---

## 📊 Logging

Structured logging with JSON output:

```python
# app/logger.py
import json
import logging
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
        }
        return json.dumps(log_data)

logger = logging.getLogger(__name__)
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger.addHandler(handler)
```

---

See [health-endpoints.md](health-endpoints.md) for probe configuration details.
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 🔗 API Endpoints

### Health Endpoints

See [health-endpoints.md](health-endpoints.md) for details.

```bash
GET /health            # Liveness probe
GET /health/ready      # Readiness probe
```

### User Management

```bash
# Get all users
GET /api/users
Authorization: Bearer <token>

# Get specific user
GET /api/users/:id
Authorization: Bearer <token>

# Create user
POST /api/users
Content-Type: application/json
Authorization: Bearer <admin-token>
{
  "name": "John Doe",
  "email": "john@example.com"
}

# Update user
PATCH /api/users/:id
Content-Type: application/json
Authorization: Bearer <admin-token>
{
  "name": "Jane Doe"
}

# Delete user
DELETE /api/users/:id
Authorization: Bearer <admin-token>
```

### Post Management

```bash
# Get all posts
GET /api/posts?limit=10&offset=0

# Get specific post
GET /api/posts/:id

# Get post comments
GET /api/posts/:id/comments

# Create post
POST /api/posts
Content-Type: application/json
Authorization: Bearer <token>
{
  "title": "My Post",
  "content": "Post content...",
  "tags": ["nextjs", "api"]
}
```

---

## 🔐 Authentication

### Bearer Token

All protected endpoints require `Authorization` header:

```bash
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..." \
  http://localhost:8000/api/users
```

### JWT Verification with FastAPI

```python
# app/middleware/auth.py
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthCredentials
from app.config import settings

security = HTTPBearer()

async def verify_token(credentials: HTTPAuthCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"]
        )
        return payload
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

### Protected Route Example

```python
# app/routers/users.py
from fastapi import APIRouter, Depends
from app.middleware.auth import verify_token
from app.models import User

router = APIRouter()

@router.get("/api/users", response_model=list[User])
async def get_users(token: dict = Depends(verify_token)):
    """Get all users (requires authentication)"""
    users = await db.user.find_many()
    return users
```

---

## 🧬 Path Parameters

### Accessing Path Parameters

```python
# app/routers/users.py
@router.get("/api/users/{user_id}", response_model=User)
async def get_user(user_id: int):
    """Get a specific user by ID"""
    user = await db.user.find_unique({"id": user_id})
    
    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )
    
    return user
```

### Nested Routes

```python
# app/routers/posts.py
@router.get("/api/posts/{post_id}/comments")
async def get_comments(post_id: int):
    """Get comments for a specific post"""
    comments = await db.comment.find_many(
        where={"post_id": post_id}
    )
    return comments
```

---

## 🔄 Query Parameters

```python
# app/routers/users.py
from typing import Optional

@router.get("/api/users")
async def list_users(
    skip: int = 0,
    limit: int = 10,
    role: Optional[str] = None
):
    """Get users with optional filtering"""
    where = {}
    if role:
        where["role"] = role
    
    users = await db.user.find_many(
        where=where,
        skip=skip,
        take=limit
    )
    
    return {"success": True, "data": users}
```

**Usage**:
```bash
GET /api/users?skip=0&limit=20&role=admin
```

---

## 📨 Request Validation with Pydantic

### Using Pydantic Models

```python
# app/models.py
from pydantic import BaseModel, EmailStr, Field
from typing import Optional

class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr
    role: str = Field(default="user", pattern="^(user|admin)$")

# app/routers/users.py
@router.post("/api/users", response_model=User, status_code=201)
async def create_user(user: UserCreate):
    """Create a new user (validates with Pydantic)"""
    new_user = await db.user.create({
        "name": user.name,
        "email": user.email,
        "role": user.role
    })
    return new_user
```

Pydantic automatically returns 422 for validation errors:
```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "invalid email format",
      "type": "value_error"
    }
  ]
}
```

---

## 🛡️ Error Handling

### Standard Error Responses

```python
# app/exceptions.py
from fastapi import HTTPException

class APIError(HTTPException):
    def __init__(
        self,
        status_code: int,
        code: str,
        message: str
    ):
        self.code = code
        super().__init__(
            status_code=status_code,
            detail={"error": message, "code": code}
        )

class NotFoundError(APIError):
    def __init__(self, message: str = "Resource not found"):
        super().__init__(404, "NOT_FOUND", message)

class UnauthorizedError(APIError):
    def __init__(self, message: str = "Unauthorized"):
        super().__init__(401, "UNAUTHORIZED", message)

# app/routers/users.py
@router.get("/api/users/{user_id}", response_model=User)
async def get_user(user_id: int):
    user = await db.user.find_unique({"id": user_id})
    if not user:
        raise NotFoundError(f"User {user_id} not found")
    return user
```

---

## 📊 Pagination

```python
# app/routers/posts.py
from math import ceil

@router.get("/api/posts")
async def list_posts(page: int = 1, limit: int = 20):
    """List posts with pagination"""
    skip = (page - 1) * limit
    
    posts, total = await Promise.all([
        db.post.find_many(skip=skip, take=limit),
        db.post.count()
    ])
    
    return {
        "success": True,
        "data": posts,
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total,
            "pages": ceil(total / limit)
        }
    }
```

**Usage**:
```bash
GET /api/posts?page=2&limit=10
```

---

## 🔄 CORS & Security

### CORS Configuration

```python
# app/main.py
from fastapi.middleware.cors import CORSMiddleware

allowed_origins = os.getenv("ALLOWED_ORIGINS", "").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["Content-Type", "Authorization"],
)
```

### Security Headers

```python
# app/middleware/security.py
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Content-Security-Policy"] = "default-src 'self'"
        return response

# app/main.py
app.add_middleware(SecurityHeadersMiddleware)
```

---

## 🧪 Testing

### Pytest Unit Tests

```python
# tests/test_users.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_get_users():
    response = client.get("/api/users")
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert isinstance(data["data"], list)

@pytest.mark.asyncio
async def test_create_user():
    response = client.post(
        "/api/users",
        json={
            "name": "John",
            "email": "john@example.com",
            "role": "user"
        }
    )
    assert response.status_code == 201
    data = response.json()
    assert data["id"] is not None
```

### Integration Tests

```bash
# Test with curl
curl -X GET http://localhost:8000/api/users \
  -H "Authorization: Bearer $TOKEN"

# Test with httpie
http GET localhost:8000/api/users "Authorization: Bearer $TOKEN"
```

---

## 📈 Rate Limiting (Optional)

```python
# app/middleware/rate_limit.py
import asyncio
from collections import defaultdict
from datetime import datetime, timedelta

class SimpleRateLimiter:
    def __init__(self, max_requests: int = 10, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests = defaultdict(list)
    
    async def is_allowed(self, client_id: str) -> bool:
        now = datetime.utcnow()
        cutoff = now - timedelta(seconds=self.window_seconds)
        
        self.requests[client_id] = [
            req_time for req_time in self.requests[client_id]
            if req_time > cutoff
        ]
        
        if len(self.requests[client_id]) < self.max_requests:
            self.requests[client_id].append(now)
            return True
        return False

rate_limiter = SimpleRateLimiter(max_requests=10, window_seconds=60)

# app/routers/users.py
@router.get("/api/users")
async def list_users(request: Request):
    client_ip = request.client.host
    if not await rate_limiter.is_allowed(client_ip):
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded"
        )
    # ... rest of handler
```

---

## 📚 Reference

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Pydantic Models](https://docs.pydantic.dev/latest/)
- [HTTP Status Codes](https://httpwg.org/specs/rfc7231.html#status.codes)
- [JWT Authentication](https://pyjwt.readthedocs.io/)

See [deployment.md](deployment.md) for production deployment patterns.

