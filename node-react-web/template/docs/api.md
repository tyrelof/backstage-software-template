# API Routes

This is a **frontend-only React application**. There are no backend API routes—only static file serving by Nginx.

---

## 📍 Routes

### GET `/`
Serves the React Single Page Application (SPA).

```bash
curl http://localhost/
# Returns: index.html (built React app)
```

**Behavior**:
- All non-existent routes are caught and redirected to `/index.html` (SPA routing)
- React Router handles client-side navigation

---

### GET `/health`
Health check endpoint for load balancers and Kubernetes probes.

```bash
curl http://localhost/health
# Returns: ok
```

**Status**: Plain HTTP 200 with body `ok`

---

## 🌐 Calling External APIs

Since this is a frontend app, all external API calls happen from the browser:

```javascript
// src/App.jsx
import { useEffect, useState } from 'react';

export default function App() {
  const [data, setData] = useState(null);

  useEffect(() => {
    // Call external backend
    const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000';
    
    fetch(`${apiUrl}/api/data`)
      .then(res => res.json())
      .then(data => setData(data))
      .catch(err => console.error(err));
  }, []);

  return <div>{data && <p>{data.message}</p>}</div>;
}
```

**Environment Setup** (Vite):
```bash
# .env.development
VITE_ENV=development
VITE_API_URL=http://localhost:3000

# .env.production
VITE_ENV=production
VITE_API_URL=https://api.example.com
```

**Build-time Substitution**:
- `VITE_*` variables are embedded at build time, not runtime
- Use ConfigMap in Kubernetes for different environments

---

## 🔐 CORS & Backend Integration

If your backend is on a different domain, configure CORS:

**Node.js/Express backend example**:
```javascript
// backend/server.js
const cors = require('cors');
const app = express();

app.use(cors({
  origin: ['http://localhost:5173', 'https://app.example.com'],
  credentials: true
}));

app.get('/api/data', (req, res) => {
  res.json({ message: 'Hello from backend' });
});
```

---

## 📦 Nginx Configuration

The Nginx configuration routes all requests to the React app:

```nginx
# nginx.conf
location / {
    root /usr/share/nginx/html;
    index index.html index.htm;
    try_files $uri $uri/ /index.html;  # SPA routing
}

location /health {
    default_type text/plain;
    return 200 "ok";
}
```

---

## 🧪 Testing

```bash
# Health check
curl http://localhost:80/health

# From Kubernetes pod
kubectl port-forward svc/my-web 8080:80
curl http://localhost:8080/health

# Check if app is served
curl http://localhost/
```

---

See [health-endpoints.md](health-endpoints.md) for probe configuration details.

