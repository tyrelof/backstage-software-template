# API & Routes

## Overview

This Next.js application provides API endpoints for data access and business logic. Routes are defined using the App Router convention in `/app/api/`.

---

## 🚀 Route Structure

```
app/api/
├── health/
│   ├── route.ts          # Liveness probe endpoint
│   └── ready/
│       └── route.ts      # Readiness probe endpoint
├── users/
│   ├── route.ts          # GET /api/users, POST /api/users
│   └── [id]/
│       └── route.ts      # GET /api/users/[id], PATCH, DELETE
├── posts/
│   ├── route.ts          # GET /api/posts
│   └── [id]/
│       ├── route.ts      # GET /api/posts/[id]
│       └── comments/
│           └── route.ts  # GET /api/posts/[id]/comments
└── middleware.ts         # Request validation, auth
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
  http://localhost:3000/api/users
```

### JWT Verification

```typescript
// lib/auth.ts
import { jwtVerify } from 'jose'

const secret = new TextEncoder().encode(process.env.JWT_SECRET!)

export async function verifyAuth(request: Request) {
  const authHeader = request.headers.get('authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    throw new Error('Missing authorization header')
  }
  
  const token = authHeader.slice(7)
  try {
    const verified = await jwtVerify(token, secret)
    return verified.payload as { userId: string }
  } catch (err) {
    throw new Error('Invalid token')
  }
}
```

### Protected Route Example

```typescript
// app/api/users/route.ts
import { verifyAuth } from '@/lib/auth'

export async function GET(request: Request) {
  try {
    const auth = await verifyAuth(request)
    const users = await db.user.findMany()
    return Response.json({ success: true, data: users })
  } catch (error) {
    return Response.json(
      { success: false, error: error.message },
      { status: 401 }
    )
  }
}
```

---

## 🧬 Dynamic Routes

### Accessing Route Parameters

```typescript
// app/api/users/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  const { id } = params
  const user = await db.user.findUnique({ where: { id } })
  
  if (!user) {
    return Response.json(
      { success: false, error: 'User not found' },
      { status: 404 }
    )
  }
  
  return Response.json({ success: true, data: user })
}
```

### Nested Routes

```typescript
// app/api/posts/[postId]/comments/route.ts
export async function GET(
  request: Request,
  { params }: { params: { postId: string } }
) {
  const { postId } = params
  const comments = await db.comment.findMany({
    where: { postId }
  })
  
  return Response.json({ success: true, data: comments })
}
```

---

## 🔄 Query Parameters

```typescript
// app/api/users/route.ts
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  
  const limit = parseInt(searchParams.get('limit') ?? '10')
  const offset = parseInt(searchParams.get('offset') ?? '0')
  const role = searchParams.get('role')  // Optional filter
  
  const users = await db.user.findMany({
    where: role ? { role } : {},
    take: limit,
    skip: offset,
  })
  
  return Response.json({ success: true, data: users })
}
```

**Usage**:
```bash
GET /api/users?limit=20&offset=40&role=admin
```

---

## 📨 Request Validation

### Using Zod Schema

```typescript
// app/api/users/route.ts
import { z } from 'zod'

const CreateUserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(['user', 'admin']).default('user'),
})

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const validated = CreateUserSchema.parse(body)
    
    const user = await db.user.create({ data: validated })
    
    return Response.json(
      { success: true, data: user },
      { status: 201 }
    )
  } catch (error) {
    if (error instanceof z.ZodError) {
      return Response.json(
        { success: false, error: 'Validation failed', issues: error.issues },
        { status: 400 }
      )
    }
    throw error
  }
}
```

---

## 🛡️ Error Handling

### Standard Error Responses

```typescript
// lib/api-errors.ts
export class APIError extends Error {
  constructor(
    public code: string,
    public statusCode: number,
    message: string
  ) {
    super(message)
  }
}

export class NotFoundError extends APIError {
  constructor(message = 'Resource not found') {
    super('NOT_FOUND', 404, message)
  }
}

export class UnauthorizedError extends APIError {
  constructor(message = 'Unauthorized') {
    super('UNAUTHORIZED', 401, message)
  }
}

// app/api/users/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const user = await db.user.findUnique({ where: { id: params.id } })
    if (!user) throw new NotFoundError('User not found')
    
    return Response.json({ success: true, data: user })
  } catch (error) {
    if (error instanceof APIError) {
      return Response.json(
        { success: false, error: error.message, code: error.code },
        { status: error.statusCode }
      )
    }
    // Unknown error
    return Response.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
```

---

## 📊 Pagination

```typescript
// app/api/posts/route.ts
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  
  const page = parseInt(searchParams.get('page') ?? '1')
  const limit = parseInt(searchParams.get('limit') ?? '20')
  
  const offset = (page - 1) * limit
  
  const [posts, total] = await Promise.all([
    db.post.findMany({ skip: offset, take: limit }),
    db.post.count(),
  ])
  
  return Response.json({
    success: true,
    data: posts,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  })
}
```

**Usage**:
```bash
GET /api/posts?page=2&limit=10
```

---

## 🔄 CORS & Security

### CORS Configuration

```typescript
// lib/cors.ts
export function setCORSHeaders(response: Response) {
  response.headers.set('Access-Control-Allow-Origin', process.env.ALLOWED_ORIGINS ?? '*')
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE')
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization')
  return response
}

// app/api/middleware.ts
export function middleware(request: Request) {
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    })
  }
}
```

### Security Headers

```typescript
// lib/security-headers.ts
export function setSecurityHeaders(response: Response) {
  response.headers.set('X-Content-Type-Options', 'nosniff')
  response.headers.set('X-Frame-Options', 'DENY')
  response.headers.set('X-XSS-Protection', '1; mode=block')
  response.headers.set('Content-Security-Policy', "default-src 'self'")
  return response
}
```

---

## 🧪 Testing

### Jest Unit Tests

```typescript
// tests/api/users.test.ts
import { GET, POST } from '@/app/api/users/route'

describe('GET /api/users', () => {
  it('returns list of users', async () => {
    const request = new Request('http://localhost/api/users')
    const response = await GET(request)
    const data = await response.json()
    
    expect(response.status).toBe(200)
    expect(data.success).toBe(true)
    expect(Array.isArray(data.data)).toBe(true)
  })
})
```

### Integration Tests

```bash
# Test with curl
curl -X GET http://localhost:3000/api/users \
  -H "Authorization: Bearer $TOKEN"

# Test with httpie
http GET localhost:3000/api/users "Authorization: Bearer $TOKEN"
```

---

## 📈 Rate Limiting (Optional)

```typescript
// lib/rate-limit.ts
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'), // 10 requests per minute
})

// app/api/users/route.ts
export async function GET(request: Request) {
  const ip = request.headers.get('x-forwarded-for') ?? '127.0.0.1'
  const { success } = await ratelimit.limit(ip)
  
  if (!success) {
    return Response.json(
      { success: false, error: 'Rate limit exceeded' },
      { status: 429 }
    )
  }
  
  // ... rest of handler
}
```

---

## 📚 Reference

- [Next.js Route Handlers](https://nextjs.org/docs/app/building-your-application/routing/route-handlers)
- [Request & Response](https://developer.mozilla.org/en-US/docs/Web/API/Request)
- [HTTP Status Codes](https://httpwg.org/specs/rfc7231.html#status.codes)

See [deployment.md](deployment.md) for production deployment patterns.

