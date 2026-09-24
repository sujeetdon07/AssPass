# Aaspaas — API Reference

## Overview

The Aaspaas REST API is versioned under:

```
/api/v1
```

All endpoints return JSON. All dates are in ISO 8601 format (UTC).

---

## Base URLs

| Environment | Base URL |
|---|---|
| Development (local) | `http://localhost:3000/api/v1` |
| Staging | `https://api-staging.aaspaas.in/api/v1` *(TBD)* |
| Production | `https://api.aaspaas.in/api/v1` *(TBD)* |

---

## Interactive Documentation

Swagger UI is available in non-production environments:

```
http://localhost:3000/api/docs
```

---

## Authentication

Authentication in Aaspaas is phone-number based using cryptographic 6-digit one-time passwords (OTP), session management with token rotation, and JWT Bearer authorization.

```
Authorization: Bearer <access_token>
```

- **Access Tokens**: Short-lived (default: 15 minutes) HMAC-SHA256 JSON Web Tokens.
- **Refresh Tokens**: Long-lived (default: 30 days) cryptographically random 64-byte tokens. Stored in hashed form (`SHA-256`) in the database.
- **Session Revocation**: On logout or reuse detection, sessions are immediately invalidated.

---

## Response Format

### Success Response

```json
{
  "success": true,
  "data": { ... }
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [ ... ]
  }
}
```

---

## Endpoints

### Health Check

#### `GET /api/v1/health`

Check the health of all backend services.

**Authentication:** None required

**Response:**

```json
{
  "success": true,
  "service": "aaspaas-api",
  "environment": "development",
  "timestamp": "2026-09-22T10:00:00.000Z",
  "database": "connected",
  "redis": "connected"
}
```

---

### Authentication Module

#### `POST /api/v1/auth/otp/request`

Initiate phone verification by requesting a 6-digit OTP challenge.

**Authentication:** None required  
**Rate Limit:** 5 requests / hour per phone number; 60-second resend cooldown

**Request Body:**

```json
{
  "phoneNumber": "+919876543210"
}
```

**Response:**

```json
{
  "success": true,
  "message": "Verification code sent to +91 ••••••3210",
  "data": {
    "maskedPhoneNumber": "+91 ••••••3210",
    "cooldownSeconds": 60,
    "expiresInSeconds": 300,
    "devOtp": "748291"
  }
}
```
*(Note: `devOtp` is only included when `NODE_ENV=development`)*

#### `POST /api/v1/auth/otp/verify`

Verify the 6-digit OTP. Creates a new user record if the phone number is not yet registered, creates an active session, and returns tokens.

**Authentication:** None required  
**Max Attempts:** 5 failed attempts per challenge before challenge is invalidated

**Request Body:**

```json
{
  "phoneNumber": "+919876543210",
  "otp": "748291",
  "deviceInfo": {
    "platform": "android",
    "deviceName": "Pixel 10 Pro"
  }
}
```

**Response:**

```json
{
  "success": true,
  "message": "Authentication successful",
  "data": {
    "user": {
      "id": "11111111-2222-3333-4444-555555555555",
      "phoneNumber": "+91 ••••••3210",
      "displayName": null,
      "avatarUrl": null,
      "accountStatus": "active",
      "onboardingCompleted": false,
      "countryCode": "IN",
      "state": null,
      "district": null,
      "city": null,
      "locality": null,
      "neighborhood": null
    },
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refreshToken": "64_byte_hex_refresh_token_value...",
      "expiresIn": 900
    }
  }
}
```

#### `POST /api/v1/auth/refresh`

Rotate the refresh token and obtain a fresh access token. Employs token rotation: the provided refresh token is invalidated and a new refresh token is issued.

**Authentication:** None required (refresh token presented in body)

**Request Body:**

```json
{
  "refreshToken": "64_byte_hex_refresh_token_value..."
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "new_64_byte_hex_refresh_token_value...",
    "expiresIn": 900
  }
}
```

#### `POST /api/v1/auth/logout`

Revoke the current session and refresh token.

**Authentication:** Bearer token required

**Response:**

```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

#### `GET /api/v1/auth/me`

Fetch the currently authenticated user's session context.

**Authentication:** Bearer token required

**Response:**

```json
{
  "success": true,
  "data": {
    "userId": "11111111-2222-3333-4444-555555555555",
    "phoneNumber": "+91 ••••••3210",
    "sessionId": "22222222-3333-4444-5555-666666666666",
    "user": { ... }
  }
}
```

---

### Users & Onboarding Module

#### `GET /api/v1/users/me`

Fetch the current user profile.

**Authentication:** Bearer token required

#### `PATCH /api/v1/users/me/onboarding`

Complete the multi-step onboarding flow by providing profile details and approximate locality. Sets `onboardingCompleted` to `true`.

**Authentication:** Bearer token required

**Request Body:**

```json
{
  "displayName": "Sujeet Sharma",
  "avatarUrl": null,
  "countryCode": "IN",
  "state": "Karnataka",
  "district": "Bengaluru Urban",
  "city": "Bengaluru",
  "locality": "Indiranagar",
  "neighborhood": "100ft Road"
}
```

**Response:**

```json
{
  "success": true,
  "message": "Onboarding completed successfully",
  "data": {
    "id": "11111111-2222-3333-4444-555555555555",
    "phoneNumber": "+91 ••••••3210",
    "displayName": "Sujeet Sharma",
    "avatarUrl": null,
    "accountStatus": "active",
    "onboardingCompleted": true,
    "countryCode": "IN",
    "state": "Karnataka",
    "district": "Bengaluru Urban",
    "city": "Bengaluru",
    "locality": "Indiranagar",
    "neighborhood": "100ft Road"
  }
}
```

---

### Localities Module

#### `GET /api/v1/localities/search`

Search curated Indian localities by name, city, state, or PIN code.

**Authentication:** None required  
**Query Parameters:**
- `q` (string, required): Query string (minimum 2 characters).
- `limit` (number, optional): Maximum results (default: 10, max: 50).

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "in-ka-blr-indiranagar",
      "displayName": "Indiranagar, Bengaluru, Karnataka",
      "countryCode": "IN",
      "state": "Karnataka",
      "district": "Bengaluru Urban",
      "city": "Bengaluru",
      "locality": "Indiranagar",
      "pincode": "560038",
      "latitude": 12.9784,
      "longitude": 77.6408
    }
  ]
}
```

#### `GET /api/v1/localities/cities`

Get the list of supported major cities and metropolitan hubs.

**Authentication:** None required

---

### Community Feed Module

#### `GET /api/v1/feed/posts`

Retrieve paginated community feed posts with cursor-based pagination and locality scoping.

**Authentication:** Bearer token required  
**Query Parameters:**
- `cursor` (string, optional): Base64 encoded `createdAt,id` cursor.
- `limit` (integer, optional): Maximum posts per page (default: 20, max: 50).
- `category` (string, optional): Filter by category (`general`, `announcement`, `question`, `recommendation`, `alert`).
- `scope` (string, optional): Locality scope: `local` (default, scoped to user city/locality) or `all`.

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "posts": [
      {
        "id": "uuid",
        "authorId": "uuid",
        "author": {
          "id": "uuid",
          "displayName": "Ashok Neighbor",
          "avatarUrl": null,
          "locality": "Koramangala",
          "city": "Bengaluru"
        },
        "content": "What are the best quiet coffee shops near 5th Block?",
        "category": "recommendation",
        "countryCode": "IN",
        "state": "Karnataka",
        "district": "Bengaluru Urban",
        "city": "Bengaluru",
        "locality": "Koramangala",
        "neighborhood": "5th Block",
        "likeCount": 3,
        "commentCount": 1,
        "currentUserLiked": true,
        "createdAt": "2026-09-22T11:00:00.000Z",
        "updatedAt": "2026-09-22T11:00:00.000Z"
      }
    ],
    "nextCursor": "MjAyNi0wOS0yMlQxMTowMDowMC4wMDBaLHV1aWQ=",
    "hasMore": false,
    "scope": "local"
  }
}
```

#### `POST /api/v1/feed/posts`

Create a new post in the user's community feed. Automatically inherits the author's onboarding locality. Coordinates are never accepted or exposed.

**Authentication:** Bearer token required  
**Rate Limit:** 10 posts / 10 minutes per user

**Request Body:**

```json
{
  "content": "Power maintenance scheduled for tomorrow 10am to 2pm in 4th block.",
  "category": "announcement",
  "neighborhood": "4th Block"
}
```

**Response (201 Created):** Returns the created post object.

#### `GET /api/v1/feed/posts/:id`

Retrieve full post details by ID including current user like status.

**Authentication:** Bearer token required  
**Response (200 OK):** Returns single post object.

#### `PATCH /api/v1/feed/posts/:id`

Update an existing post. Server strictly verifies that `currentUserId === post.authorId`.

**Authentication:** Bearer token required  
**Request Body:**

```json
{
  "content": "Updated power maintenance hours: 11am to 1pm.",
  "category": "announcement"
}
```

**Response (200 OK):** Returns updated post object.  
**Errors:** `403 Forbidden` if not author, `404 Not Found` if deleted/missing.

#### `DELETE /api/v1/feed/posts/:id`

Soft-delete a post authored by the current user.

**Authentication:** Bearer token required  
**Response (204 No Content)**  
**Errors:** `403 Forbidden` if not author, `404 Not Found` if deleted/missing.

#### `POST /api/v1/feed/posts/:id/like`

Like a post. Idempotent — multiple calls from the same user do not inflate like counts.

**Authentication:** Bearer token required  
**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "liked": true,
    "likeCount": 4
  }
}
```

#### `DELETE /api/v1/feed/posts/:id/like`

Remove a like from a post. Idempotent.

**Authentication:** Bearer token required  
**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "liked": false,
    "likeCount": 3
  }
}
```

#### `GET /api/v1/feed/posts/:id/comments`

Retrieve paginated comments for a post ordered chronologically.

**Authentication:** Bearer token required  
**Query Parameters:**
- `cursor` (string, optional): Base64 encoded cursor.
- `limit` (integer, optional): Maximum comments per page (default: 20, max: 50).

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "comments": [
      {
        "id": "uuid",
        "postId": "uuid",
        "authorId": "uuid",
        "author": {
          "id": "uuid",
          "displayName": "Bindu Neighbor",
          "avatarUrl": null,
          "locality": "Indiranagar"
        },
        "content": "Thanks for the heads up!",
        "createdAt": "2026-09-22T11:05:00.000Z",
        "updatedAt": "2026-09-22T11:05:00.000Z"
      }
    ],
    "nextCursor": null,
    "hasMore": false
  }
}
```

#### `POST /api/v1/feed/posts/:id/comments`

Post a comment on a post. Atomically increments post `commentCount`.

**Authentication:** Bearer token required  
**Rate Limit:** 30 comments / 10 minutes per user

**Request Body:**

```json
{
  "content": "Thanks for the heads up!"
}
```

**Response (201 Created):** Returns created comment object.

#### `DELETE /api/v1/feed/comments/:id`

Soft-delete a comment authored by the current user. Atomically decrements post `commentCount`.

**Authentication:** Bearer token required  
**Response (204 No Content)**  
**Errors:** `403 Forbidden` if not comment author.

#### `POST /api/v1/feed/posts/:id/report`

Report a post for Trust & Safety review. Duplicate reports by the same user for the same post are prevented via database constraints.

**Authentication:** Bearer token required  
**Rate Limit:** 10 reports / hour per user

**Request Body:**

```json
{
  "reason": "spam",
  "details": "Unsolicited commercial advertisements"
}
```

**Response (200 OK):** `{"message": "Thank you. Your report has been submitted for review."}`  
**Errors:** `409 Conflict` if already reported by this user.

#### `POST /api/v1/feed/comments/:id/report`

Report a comment for Trust & Safety review.

**Authentication:** Bearer token required  
**Request Body:**

```json
{
  "reason": "harassment",
  "details": "Abusive tone"
}
```

**Response (200 OK):** `{"message": "Thank you. Your report has been submitted for review."}`  
**Errors:** `409 Conflict` if already reported by this user.

---

### Nearby Discovery Module (Phase 4)

#### `GET /api/v1/nearby/posts`

Discover public community posts within a specified geographic radius from given coordinates using PostGIS spatial indexing. Designed with strict location privacy: raw coordinates and author phone numbers are never returned; distance is formatted into privacy-safe rounded bands.

**Authentication:** Bearer token required  
**Rate Limit:** 60 requests / minute per user (Redis backed)  
**Query Parameters:**
- `latitude` (number, required): WGS84 latitude between -90.0 and +90.0.
- `longitude` (number, required): WGS84 longitude between -180.0 and +180.0.
- `radius` (integer, optional): Radius in kilometers (allowed: 1, 3, 5, 10, 20; default: 5).
- `category` (string, optional): Filter by post category (`general`, `announcement`, `question`, `recommendation`, `alert`).
- `cursor` (string, optional): Base64-encoded deterministic cursor (`distance_meters,created_at,id`).
- `limit` (integer, optional): Page size between 1 and 50 (default: 20).

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "4be42a8b-326b-4066-ae05-df70cc551e96",
        "authorId": "c33b76cf-06f1-4354-93ff-fce6780c1097",
        "author": {
          "id": "c33b76cf-06f1-4354-93ff-fce6780c1097",
          "displayName": "Koramangala Resident",
          "avatarUrl": null,
          "locality": "Koramangala",
          "city": "Bengaluru"
        },
        "content": "Koramangala 5th Block community cleanup drive this weekend!",
        "category": "announcement",
        "locality": "Koramangala",
        "city": "Bengaluru",
        "likeCount": 0,
        "commentCount": 0,
        "currentUserLiked": false,
        "isOwnPost": true,
        "distance": "Nearby",
        "distanceMeters": 100,
        "createdAt": "2026-09-22T12:41:00.000Z",
        "updatedAt": "2026-09-22T12:41:00.000Z"
      }
    ],
    "nextCursor": null,
    "hasMore": false,
    "radiusKm": 1
  }
}
```

**Privacy Guarantees:**
- Posts store safe locality centroids, NOT author private GPS fixes.
- Distance is computed server-side via PostGIS `ST_Distance`.
- Distance is banded: `< 100m` -> `"Nearby"`, `100m - 999m` -> `"${Math.round(m / 50) * 50} m away"`, `1km - 9.9km` -> `"${(m / 1000).toFixed(1)} km away"`, `10km+` -> `"${Math.round(m / 1000)} km away"`.
- Zero GPS coordinates, zero phone numbers, zero email addresses exposed in response.

---

### Marketplace Module (Phase 6)

A hyperlocal peer-to-peer marketplace facilitating local buying, selling, and giving away of pre-owned and new goods among neighborhood residents.

#### `GET /api/v1/marketplace/listings`

Discover marketplace listings with multi-attribute filtering, PostGIS radius search, privacy-safe distance calculation, and keyset cursor pagination.

**Authentication:** Optional / Bearer token (Bearer token enables `isFavorited` and `isOwner` projections)  
**Rate Limit:** 60 requests / minute per user (Redis backed)  
**Query Parameters:**
- `query` (string, optional): Keyword search across listing title and description.
- `category` (string, optional): Filter by category (`electronics`, `mobiles`, `computers`, `furniture`, `home_kitchen`, `vehicles`, `books`, `fashion`, `kids`, `sports`, `other`).
- `condition` (string, optional): Filter by item condition (`new`, `like_new`, `good`, `fair`, `used`).
- `minPrice` (number, optional): Minimum price filter in INR.
- `maxPrice` (number, optional): Maximum price filter in INR (`0` for free giveaways).
- `locality` (string, optional): Locality text filter.
- `city` (string, optional): City text filter.
- `latitude` (number, optional): Current latitude for radius/nearest discovery.
- `longitude` (number, optional): Current longitude for radius/nearest discovery.
- `radius` (integer, optional): Radius in kilometers (1–50 km, default: 5 km).
- `sortBy` (string, optional): Sort order (`newest`, `price_asc`, `price_desc`, `nearest`). Default: `newest`.
- `cursor` (string, optional): Base64-encoded deterministic cursor (`sort_val,created_at,id`).
- `limit` (integer, optional): Page size between 1 and 50 (default: 20).

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "f9b686e2-2212-459d-ae37-205de923084f",
        "sellerId": "9e6aec3c-2a45-42b8-834a-ff2581c78474",
        "seller": {
          "id": "9e6aec3c-2a45-42b8-834a-ff2581c78474",
          "displayName": "Aakash Verma",
          "avatarUrl": null,
          "locality": "Indiranagar",
          "city": "Bengaluru"
        },
        "title": "Solid Teakwood Study Table",
        "description": "Minimalist study desk made of natural teakwood with two drawers.",
        "category": "furniture",
        "price": "4500.00",
        "currency": "INR",
        "condition": "like_new",
        "status": "active",
        "countryCode": "IN",
        "state": "Karnataka",
        "district": "Bengaluru Urban",
        "city": "Bengaluru",
        "locality": "Indiranagar",
        "neighborhood": null,
        "favoriteCount": 1,
        "isFavorited": false,
        "isOwner": false,
        "images": [
          {
            "id": "img-uuid",
            "url": "https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd",
            "displayOrder": 0
          }
        ],
        "distance": "Nearby",
        "distanceMeters": 100,
        "createdAt": "2026-09-23T09:17:38.000Z",
        "updatedAt": "2026-09-23T09:17:38.000Z"
      }
    ],
    "nextCursor": null,
    "hasMore": false
  }
}
```

#### `POST /api/v1/marketplace/listings`

Create a new marketplace listing. Resolves location safely to locality centroid, never saving private precise device GPS coordinates.

**Authentication:** Bearer token required  
**Rate Limit:** 20 listings / hour per user  
**Request Body:**

```json
{
  "title": "Solid Teakwood Study Table",
  "description": "Minimalist study desk made of natural teakwood with two drawers.",
  "category": "furniture",
  "price": 4500,
  "condition": "like_new",
  "locality": "Indiranagar",
  "city": "Bengaluru",
  "images": [
    { "url": "https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd", "displayOrder": 0 }
  ]
}
```

**Response (201 Created):** Returns created listing response object.

#### `GET /api/v1/marketplace/listings/my-listings`

Retrieve all listings posted by the authenticated user, optionally filtered by status (`active`, `sold`, `archived`).

**Authentication:** Bearer token required  
**Query Parameters:**
- `status` (string, optional): `active`, `sold`, or `archived`.
- `limit` (integer, optional): Page size (default: 50).

**Response (200 OK):** Returns paginated items created by the authenticated user with `isOwner: true`.

#### `GET /api/v1/marketplace/listings/:id`

Retrieve a single marketplace listing by ID with public seller projection and favorite status.

**Authentication:** Optional / Bearer token  
**Response (200 OK):** Returns listing response object.  
**Errors:** `404 Not Found` if deleted or nonexistent.

#### `PATCH /api/v1/marketplace/listings/:id`

Update title, description, price, condition, or images of an existing listing.

**Authentication:** Bearer token required (Owner only)  
**Response (200 OK):** Returns updated listing object.  
**Errors:** `403 Forbidden` if caller is not the listing owner.

#### `PATCH /api/v1/marketplace/listings/:id/status`

Update the lifecycle status of a listing (`active`, `sold`, `archived`).

**Authentication:** Bearer token required (Owner only)  
**Request Body:**

```json
{
  "status": "sold"
}
```

**Response (200 OK):** Returns updated listing object.  
**Errors:** `403 Forbidden` if caller is not the listing owner.

#### `DELETE /api/v1/marketplace/listings/:id`

Soft-delete / archive a listing. Soft-deleted items are excluded from discovery searches and return 404 on direct lookup.

**Authentication:** Bearer token required (Owner only)  
**Response (200 OK):** `{"message": "Listing deleted successfully."}`  
**Errors:** `403 Forbidden` if caller is not the listing owner.

#### `POST /api/v1/marketplace/listings/:id/favorite`

Favorite a listing. Atomically increments listing `favoriteCount`.

**Authentication:** Bearer token required  
**Response (200 OK):** `{"message": "Listing favorited."}`

#### `DELETE /api/v1/marketplace/listings/:id/favorite`

Unfavorite a listing. Atomically decrements listing `favoriteCount`.

**Authentication:** Bearer token required  
**Response (200 OK):** `{"message": "Listing unfavorited."}`

#### `POST /api/v1/marketplace/listings/:id/report`

Report a listing for Trust & Safety review. Duplicate reports by the same user are prevented with a 409 Conflict.

**Authentication:** Bearer token required  
**Rate Limit:** 10 reports / hour per user  
**Request Body:**

```json
{
  "reason": "spam",
  "details": "Suspicious commercial listing"
}
```

**Response (200 OK):** `{"message": "Thank you. Your report has been submitted for review."}`  
**Errors:** `400 Bad Request` if reporting own listing; `409 Conflict` if already reported.

---

## Planned Endpoints (Future Phases)

The following modules will be added in subsequent phases.

### Phase 7 — Businesses & Services

```
GET    /api/v1/businesses
POST   /api/v1/businesses
GET    /api/v1/businesses/:id
GET    /api/v1/services
POST   /api/v1/services
GET    /api/v1/services/:id
```

### Phase 8 — Events

```
GET    /api/v1/events
POST   /api/v1/events
GET    /api/v1/events/:id
POST   /api/v1/events/:id/rsvp
```

### Phase 9 — Messaging

```
GET    /api/v1/conversations
POST   /api/v1/conversations
GET    /api/v1/conversations/:id/messages
POST   /api/v1/conversations/:id/messages
```

### Phase 10 — Notifications

```
GET    /api/v1/notifications
PATCH  /api/v1/notifications/:id/read
PATCH  /api/v1/notifications/read-all
GET    /api/v1/notifications/preferences
PATCH  /api/v1/notifications/preferences
```

---

## API Versioning

Future API versions will use:
```
/api/v2
```

Version 1 endpoints will continue to work during any migration period.

---

## Rate Limiting (Planned)

| Endpoint category | Limit |
|---|---|
| Auth (OTP send) | 5 requests / 10 minutes per IP |
| Auth (general) | 20 requests / minute per IP |
| Public read endpoints | 100 requests / minute per IP |
| Authenticated endpoints | 300 requests / minute per user |

---

## Error Codes

| Code | HTTP Status | Description |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Request body failed validation |
| `UNAUTHORIZED` | 401 | Missing or invalid authentication |
| `FORBIDDEN` | 403 | Authenticated but insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource already exists |
| `RATE_LIMITED` | 429 | Too many requests |
| `SERVER_ERROR` | 500 | Unexpected server error |
