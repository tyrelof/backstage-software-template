# API Routes

This Node.js/Express application provides REST API endpoints for data access and business logic. Routes are organized in `/src/routes/`.

---

## 🚀 Route Structure

```
src/
├── routes/
│   ├── api.js              # Main API router
│   ├── health.js           # Health endpoints
│   └── users.js            # Users endpoints (example)
├── controllers/
│   └── userController.js   # Business logic
└── middleware/
    ├── auth.js             # Authentication
    └── validation.js       # Request validation
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
  "statusCode": 404,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 🔌 Core Endpoints

### Health Endpoints

```javascript
// src/routes/health.js
const express = require('express');
const router = express.Router();

// Liveness probe
router.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
});

// Readiness probe
router.get('/ready', (req, res) => {
  // Check dependencies (DB, cache, etc.)
  res.json({
    status: 'ready',
    dependencies: {
      database: 'connected',
      cache: 'connected',
    },
  });
});

module.exports = router;
```

**Usage**:
```bash
GET /health              # Liveness probe
GET /health/ready        # Readiness probe
```

---

## 👥 Users Endpoints (Example)

### List Users

```javascript
// src/routes/users.js
const express = require('express');
const { auth, validate } = require('../middleware');
const { getUsers } = require('../controllers/userController');

router.get('/', auth, async (req, res, next) => {
  try {
    const users = await getUsers(req.query);
    res.json({
      success: true,
      data: users,
      count: users.length,
    });
  } catch (err) {
    next(err);
  }
});
```

**Request**:
```bash
GET /api/users
Authorization: Bearer <token>
```

**Response** (200):
```json
{
  "success": true,
  "data": [
    { "id": 1, "name": "John", "email": "john@example.com" },
    { "id": 2, "name": "Jane", "email": "jane@example.com" }
  ],
  "count": 2
}
```

### Get Single User

```javascript
router.get('/:id', auth, async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        code: 'USER_NOT_FOUND',
      });
    }
    res.json({
      success: true,
      data: user,
    });
  } catch (err) {
    next(err);
  }
});
```

**Request**:
```bash
GET /api/users/1
Authorization: Bearer <token>
```

**Response** (200):
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "John",
    "email": "john@example.com",
    "createdAt": "2024-01-01T00:00:00Z"
  }
}
```

### Create User

```javascript
const { body, validationResult } = require('express-validator');

router.post('/',
  auth,
  validate([
    body('name').notEmpty().withMessage('Name is required'),
    body('email').isEmail().withMessage('Valid email required'),
  ]),
  async (req, res, next) => {
    try {
      const user = await User.create(req.body);
      res.status(201).json({
        success: true,
        data: user,
      });
    } catch (err) {
      next(err);
    }
  }
);
```

**Request**:
```bash
POST /api/users
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Alice",
  "email": "alice@example.com"
}
```

**Response** (201):
```json
{
  "success": true,
  "data": {
    "id": 3,
    "name": "Alice",
    "email": "alice@example.com"
  }
}
```

---

## 🔐 Authentication

All protected routes require Bearer token in `Authorization` header:

```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/users
```

**Implementation**:
```javascript
// src/middleware/auth.js
module.exports = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'No token provided',
    });
  }
  // Verify token...
  next();
};
```

---

## ✅ Input Validation

Uses express-validator for request validation:

```javascript
// src/middleware/validation.js
const { body, validationResult, param } = require('express-validator');

const validateUser = [
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Name is required')
    .isLength({ min: 2 })
    .withMessage('Name must be at least 2 characters'),
  
  body('email')
    .isEmail()
    .withMessage('Valid email is required'),
];

module.exports = validateUser;
```

---

## 🧪 Testing Endpoints

### Using curl

```bash
# Health check
curl http://localhost:3000/health

# List users (with auth)
curl -H "Authorization: Bearer <token>" \
  http://localhost:3000/api/users

# Create user
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"Bob","email":"bob@example.com"}' \
  http://localhost:3000/api/users
```

### Using Postman / Insomnia

1. **Collection**: Import the API routes
2. **Environment**: Set `BASE_URL=http://localhost:3000`, `TOKEN=<your-token>`
3. **Tests**: Run requests with auth headers

---

## 🚨 Error Handling

Express middleware catches errors and returns consistent responses:

```javascript
// src/app.js
app.use((err, req, res, next) => {
  console.error('Error:', err);
  
  res.status(err.statusCode || 500).json({
    success: false,
    error: err.message,
    code: err.code,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});
```

**Common Errors**:
- `400` - Bad Request (validation failed)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (resource doesn't exist)
- `500` - Internal Server Error

---

## 📊 Logging

All requests are logged via Morgan middleware:

```javascript
// src/app.js
const morgan = require('morgan');

app.use(morgan('combined'));  // Standard format
// Or JSON format for production:
app.use(morgan(':remote-addr :method :url :status :response-time ms'));
```

**Logs show**:
- Request method, URL, query parameters
- Response status code
- Response time
- IP address, user agent

---

See [health-endpoints.md](health-endpoints.md) for probe configuration details.

