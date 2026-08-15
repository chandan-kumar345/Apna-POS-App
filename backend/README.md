# Apna POS Backend API

Production-ready REST API backend for **Apna POS — Smart Restaurant Billing, KDS & Analytics**, built with **Node.js**, **Express.js**, **MongoDB**, and **JWT Authentication**.

---

## 🛠️ Tech Stack & Architecture

- **Runtime**: Node.js (v18+ or v20+ recommended)
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose ODM
- **Authentication**: JWT (Access Token 15m + Refresh Token 7d with rotation & revocation)
- **Password Hashing**: bcryptjs (12 salt rounds)
- **Validation**: Joi
- **Security**: Helmet, CORS, Rate Limiting (1000 requests/15min)
- **Testing**: Jest + Supertest with `mongodb-memory-server`
- **Architecture**: Layered Clean Architecture (Routes -> Middleware/Validators -> Controllers -> Services -> Models)

---

## 📁 Project Structure

```
backend/
├── src/
│   ├── config/
│   │   ├── db.js             # MongoDB connection manager
│   │   └── env.js            # Validated environment configuration
│   │
│   ├── models/
│   │   ├── User.js           # User schema (email, role, onboarding status)
│   │   ├── Business.js       # Business profile, GeoJSON address, order settings
│   │   └── RefreshToken.js   # Refresh token storage with TTL index & revocation
│   │
│   ├── controllers/
│   │   ├── authController.js       # Register, Login, Refresh, Logout, /auth/me
│   │   ├── onboardingController.js # Steps 1-4, Status, Server-side Completion
│   │   └── profileController.js    # Profile query operations
│   │
│   ├── routes/
│   │   ├── authRoutes.js           # /api/v1/auth/*
│   │   ├── onboardingRoutes.js     # /api/v1/onboarding/*
│   │   ├── profileRoutes.js        # /api/v1/profile/*
│   │   └── index.js                # Root v1 router
│   │
│   ├── middleware/
│   │   ├── authMiddleware.js       # Bearer JWT verification & req.user attachment
│   │   ├── errorMiddleware.js      # Centralized error handler & 404 handler
│   │   └── validationMiddleware.js # Joi schema validation wrapper
│   │
│   ├── validators/
│   │   ├── authValidator.js        # Auth input rules (email, strong password)
│   │   └── onboardingValidator.js  # Onboarding rules (conditional GST, GeoJSON)
│   │
│   ├── services/
│   │   ├── authService.js          # Authentication business logic
│   │   └── tokenService.js         # JWT lifecycle & rotation logic
│   │
│   ├── utils/
│   │   ├── ApiError.js             # Standardized HTTP error class
│   │   └── ApiResponse.js          # Standardized HTTP success envelope
│   │
│   ├── app.js                      # Express app setup & security middleware
│   └── server.js                   # Server bootstrap & graceful shutdown
│
├── tests/
│   ├── setup.js                    # In-memory MongoDB test environment
│   ├── auth.test.js                # Auth integration test suite
│   └── onboarding.test.js          # Onboarding integration test suite
│
├── .env.example                    # Environment variables template
├── .gitignore
├── package.json
├── postman_collection.json         # Postman collection with dynamic tokens
└── README.md
```

---

## 🚀 Quick Setup & Installation

### 1. Prerequisites
- **Node.js**: `v18.0.0` or higher
- **MongoDB**: Community Server running locally on `localhost:27017` (or MongoDB Atlas connection string)

### 2. Install Dependencies
```bash
cd backend
npm install
```

### 3. Environment Configuration
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

Default `.env` values:
```ini
PORT=5000
NODE_ENV=development
MONGODB_URI=mongodb://127.0.0.1:27017/apna_pos
JWT_ACCESS_SECRET=apna_pos_jwt_access_super_secret_key_2026_production_ready_token_key_128
JWT_REFRESH_SECRET=apna_pos_jwt_refresh_super_secret_key_2026_production_ready_token_key_256
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
CLIENT_URL=*
```

---

## 💻 Running the Server

### Development Server (with auto-restart)
```bash
npm run dev
```

### Production Server
```bash
npm start
```

### Running Automated Tests
```bash
npm test
```

---

## 📑 API Endpoints Reference

All endpoints are versioned under `/api/v1`.

### 1. Authentication APIs (`/api/v1/auth`)

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/api/v1/auth/register` | Public | Register new user with email & password |
| `POST` | `/api/v1/auth/login` | Public | Login with email & password |
| `POST` | `/api/v1/auth/refresh` | Public | Refresh expired access token using refresh token |
| `POST` | `/api/v1/auth/logout` | Public | Revoke refresh token & terminate session |
| `GET`  | `/api/v1/auth/me` | Bearer JWT | Get authenticated user info & business data |

### 2. Onboarding APIs (`/api/v1/onboarding`)

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `PATCH` | `/api/v1/onboarding/profile` | Bearer JWT | Step 1: Save/Update profile details |
| `PATCH` | `/api/v1/onboarding/business` | Bearer JWT | Step 2: Save/Update business details |
| `PATCH` | `/api/v1/onboarding/address` | Bearer JWT | Step 3: Save/Update address with GeoJSON Point |
| `PATCH` | `/api/v1/onboarding/order-settings` | Bearer JWT | Step 4: Save/Update order, GST & table settings |
| `GET`   | `/api/v1/onboarding/status` | Bearer JWT | Get current onboarding progress & next step |
| `POST`  | `/api/v1/onboarding/complete` | Bearer JWT | Backend verification and completion lock |

---

## 📦 Request / Response Examples

### Register (`POST /api/v1/auth/register`)
**Request:**
```json
{
  "email": "owner@example.com",
  "password": "SecurePassword@123"
}
```
**Response (201 Created):**
```json
{
  "statusCode": 201,
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": "66bc8d01f5e2...",
      "email": "owner@example.com",
      "role": "owner",
      "onboardingCompleted": false,
      "onboardingStep": 0
    },
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "eyJhbGciOi...",
    "tokenType": "Bearer",
    "expiresIn": "15m"
  }
}
```

### Standard Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "fields": {
      "password": "Password must contain at least 1 uppercase letter, 1 lowercase letter, 1 number, and 1 special character"
    }
  }
}
```

---

## 🧪 Postman Collection

Import `postman_collection.json` into Postman. It contains:
- Pre-configured requests for all endpoints
- Automatic token variable extraction (tokens from Register/Login/Refresh are auto-saved to collection variable `{{accessToken}}`)
- Complete example JSON payloads for all 4 onboarding steps
