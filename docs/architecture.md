# Aaspaas — Architecture Overview

## Purpose

This document describes the high-level architecture of the Aaspaas platform.

---

## System Overview

```
┌─────────────────────────────────────────────┐
│             Flutter Mobile App              │
│         (Android / iOS / Tablet)            │
│                                             │
│  Riverpod  │  GoRouter  │  Dio  │  M3 UI   │
└──────────────────┬──────────────────────────┘
                   │ HTTPS / REST
                   │ WebSocket (future)
┌──────────────────▼──────────────────────────┐
│              NestJS Backend                 │
│           REST API  /api/v1                 │
│                                             │
│  Guards │ Pipes │ Interceptors │ Filters    │
└──────┬──────────────────────────┬───────────┘
       │                          │
┌──────▼───────┐        ┌─────────▼──────────┐
│  PostgreSQL  │        │       Redis         │
│  + PostGIS   │        │  Cache / Sessions   │
│  (Primary DB)│        │  / Pub-Sub          │
└──────────────┘        └────────────────────┘
```

---

## Mobile Architecture

### Technology

- **Framework:** Flutter (Dart)
- **State Management:** Riverpod
- **Navigation:** GoRouter
- **Networking:** Dio (centralized API client)
- **Secure Storage:** flutter_secure_storage
- **Local Storage:** shared_preferences

### Directory Structure

```
lib/
├── core/
│   ├── config/         # App configuration & environment
│   ├── constants/      # App-wide constants
│   ├── errors/         # Error types and normalization
│   ├── network/        # Dio client, interceptors, error handling
│   ├── routing/        # GoRouter configuration
│   ├── storage/        # Secure + local storage abstractions
│   ├── theme/          # Material 3 theme tokens
│   └── utils/          # Shared utilities
│
├── shared/
│   ├── models/         # Shared data models
│   └── widgets/        # Reusable UI components
│
├── features/
│   └── foundation/     # Phase 0 foundation screen
│       └── (auth/, home/, communities/, etc. — added per phase)
│
└── main.dart
```

### Feature Structure (applied per feature from Phase 2+)

```
features/<feature_name>/
├── data/
│   ├── datasources/    # Remote and local data sources
│   ├── models/         # Data layer models (JSON/API)
│   └── repositories/   # Repository implementations
│
├── domain/
│   ├── entities/       # Domain entities
│   ├── repositories/   # Repository abstractions
│   └── usecases/       # Business logic
│
└── presentation/
    ├── screens/        # Screen widgets
    ├── widgets/        # Feature-specific widgets
    └── providers/      # Riverpod providers
```

### State Management Pattern

Riverpod providers are the single source of truth. The dependency graph is:

```
UI Widgets
  → Providers (Riverpod)
    → Repositories (domain)
      → Data Sources (data)
        → API Client (Dio) / Storage / Device APIs
```

---

## Backend Architecture

### Technology

- **Framework:** NestJS (TypeScript)
- **API Style:** REST — `/api/v1`
- **Real-time:** WebSocket / Socket.IO *(Phase 9)*
- **ORM:** TypeORM
- **Database:** PostgreSQL 16 + PostGIS 3.4
- **Cache:** Redis 7.2

### Directory Structure

```
src/
├── config/             # Environment configuration (ConfigModule)
├── common/
│   ├── decorators/     # Custom decorators
│   ├── filters/        # Global exception filters
│   ├── guards/         # Auth guards (JWT, etc.)
│   ├── interceptors/   # Logging, transform interceptors
│   ├── middleware/      # Request middleware
│   ├── pipes/          # Validation pipes
│   └── utils/          # Shared utilities
├── database/           # TypeORM data source configuration
├── health/             # Health check endpoint
├── app.module.ts       # Root application module
└── main.ts             # Application entry point
```

### Backend Modules Status

| Module | Status | Phase | Description |
|---|---|---|---|
| auth | **Implemented** | Phase 2 | Phone OTP, RFC 7519 HMAC-SHA256 JWT, session rotation & revocation |
| users | **Implemented** | Phase 2 | User entity, profile, multi-step onboarding completion |
| localities | **Implemented** | Phase 2 | Indian locality search, city listings, privacy-preserving location hierarchy |
| posts | **Implemented** | Phase 3 | Hyperlocal feed, posts |
| comments | **Implemented** | Phase 3 | Nested comments on posts |
| reactions | **Implemented** | Phase 3 | Community reactions and likes |
| communities | **Implemented** | Phase 5 | Local hubs & neighborhoods |
| marketplace | **Implemented** | Phase 6 | Peer-to-peer buy/sell/giveaway listings, PostGIS discovery, images, favorites, reports |
| businesses | Planned | Phase 7 | Local business directory & profiles |
| services | Planned | Phase 7 | Local home & professional services |
| events | Planned | Phase 8 | Local community events & RSVPs |
| messages | Planned | Phase 9 | Direct & group chats (WebSocket) |
| notifications | Planned | Phase 10 | Real-time push & in-app alerts |
| reports | Planned | Phase 11 | User & content reporting |
| moderation | Planned | Phase 11 | Content review & strike management |
| uploads | Planned | Phase 10+ | Media asset storage |
| admin | Planned | Phase 12 | Next.js admin portal |

---

## Phase 2: Authentication & Onboarding Architecture

```
┌─────────────────┐       1. Request OTP (+91...)       ┌──────────────────┐
│                 │────────────────────────────────────▶│                  │
│                 │◀────────────────────────────────────│                  │
│                 │     2. Masked Phone + Dev OTP       │   NestJS Auth    │
│  Flutter Client │                                     │      Module      │
│  (Auth Flow)    │       3. Verify OTP (6 digits)      │                  │
│                 │────────────────────────────────────▶│  • Rate limiting │
│                 │◀────────────────────────────────────│  • Challenge TTL │
│                 │     4. JWT Access + Refresh Token   │  • User creation │
└────────┬────────┘                                     └────────┬─────────┘
         │                                                       │
         │ 5. Store Tokens                                       │ 6. Save Session
         ▼                                                       ▼
┌─────────────────┐                                     ┌──────────────────┐
│ Flutter Secure  │                                     │ PostgreSQL       │
│ Storage         │                                     │ (auth_sessions,  │
│ (Encrypted)     │                                     │  users)          │
└─────────────────┘                                     └──────────────────┘
```

### Mobile Authentication & Routing Guard
- **Storage Layer**: Access and refresh tokens are strictly stored using `FlutterSecureStorage` (`flutter_secure_storage` package). Non-sensitive preferences (e.g. theme mode) remain in `SharedPreferences`.
- **Dio Interceptor**: `AuthInterceptor` is implemented as a `QueuedInterceptor`. When a `401 Unauthorized` is returned:
  1. It locks subsequent incoming requests.
  2. Issues a single `/auth/refresh` request with the stored refresh token.
  3. Updates secure storage with newly issued tokens.
  4. Retries the failed original request with the fresh access token.
  5. If the refresh fails or token is revoked, it triggers `authController.logout()` and routes to `/welcome`.
- **GoRouter Guard**: Reactive `redirect` callback monitors `authControllerProvider`:
  - `AuthUnauthenticated` → Redirects unauthenticated users trying to access protected shell tabs (`/`, `/feed`, etc.) to `/welcome`.
  - `AuthOnboardingRequired` → Redirects authenticated users who have not completed profile & locality setup to `/onboarding/profile`.
  - `AuthAuthenticated` → Redirects authenticated users away from `/welcome` or `/auth/*` directly to `/` (home shell).

### Token Security & Session Management
- **Cryptographic OTP Generation**: 6-digit cryptographically random numeric strings via `node:crypto.randomInt`. Challenges stored in Redis with 300-second TTL and hashed values.
- **Rate Limiting & Attempt Locking**: Max 5 OTP requests per hour per phone number. 60-second cooldown between resends. 5 failed verification attempts permanently burn the challenge.
- **Native RFC 7519 HMAC-SHA256 JWTs**: Implemented with zero external unverified dependencies via `node:crypto.createHmac`.
- **Token Rotation**: Every refresh token usage invalidates the previous token and issues a new one. Stored in database as SHA-256 hash to prevent credential harvesting even if the database is dumped.
- **Provider Abstraction**: Decoupled `OtpProvider` interface allowing seamless switching between `DevelopmentOtpProvider` (in dev/test) and production SMS gateways (e.g., Twilio, AWS SNS, MSG91) in production.

---

## Database Strategy

### PostgreSQL

PostgreSQL is the primary relational database. All business data is stored here.

Design principles:
- Proper primary keys, foreign keys, indexes
- Unique constraints
- `created_at` / `updated_at` timestamps on all tables
- Soft deletion (`deleted_at`) where appropriate
- No arbitrary JSON blobs where relational structure is more appropriate

### PostGIS

PostGIS extends PostgreSQL with geospatial capabilities.

Used for:
- Storing user-consented location coordinates at locality level
- Radius-based queries (users, posts, events, businesses within N km)
- Geographic area filtering

Privacy rule: **User exact residential coordinates are never publicly exposed.** Location is abstracted to locality/neighborhood level.

Planned PostGIS queries:
```sql
-- Users within 5 km
SELECT * FROM users
WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, 5000);

-- Posts within 10 km
SELECT * FROM posts
WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, 10000);
```

### Location Hierarchy

```
Country → State → District → City → Locality → Neighborhood
```

---

## Phase 3 — Community Feed Architecture

### Data Models & Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                            User                             │
└──────────────┬──────────────────┬──────────────────┬────────┘
               │ 1                │ 1                │ 1
               │                  │                  │
               ▼ *                ▼ *                ▼ *
┌─────────────────────────┐┌──────────────┐┌──────────────────┐
│          Post           ││ PostReaction ││     Comment      │
│ ─────────────────────── ││ ──────────── ││ ──────────────── │
│ id (UUID, PK)           ││ id (UUID, PK)││ id (UUID, PK)    │
│ authorId (FK -> User)   ││ postId (FK)  ││ postId (FK)      │
│ content (Text)          ││ userId (FK)  ││ authorId (FK)    │
│ category (Enum)         ││ reactionType ││ content (Text)   │
│ locality, city, state   ││ [post,user,  ││ createdAt, updAt │
│ likeCount, commentCount ││  type] UNIQUE││ deletedAt (Soft) │
│ createdAt, updatedAt    │└──────────────┘└──────────────────┘
│ deletedAt (Soft delete) │
└──────────────┬──────────┘
               │ 1
               ▼ *
┌─────────────────────────┐
│         Report          │
│ ─────────────────────── │
│ id (UUID, PK)           │
│ reporterId (FK -> User) │
│ targetType (post/comm)  │
│ targetId (UUID)         │
│ reason (Enum), details  │
│ [reporter,type,id] UNIQ │
└─────────────────────────┘
```

### Privacy & Locality Scoping

1. **Locality Inheritance:** When a post is created, it automatically inherits the author's onboarding locality (`locality`, `neighborhood`, `city`, `state`, `countryCode`).
2. **Coordinate Protection:** The feed API strictly rejects and never exposes exact GPS coordinates (lat/long) in any feed response.
3. **Deterministic Cursor Pagination:** Feeds use stable cursor encoding `base64(createdAt.toISOString() + ',' + id)` with `WHERE (createdAt < :cursorDate OR (createdAt = :cursorDate AND id < :cursorId))` ordering by `createdAt DESC, id DESC`.

### Optimistic UI & Riverpod Architecture

- **State Representation:** `FeedState` with discrete `FeedStatus` lifecycle (`initial`, `loading`, `refreshing`, `loaded`, `loadingMore`, `error`).
- **Optimistic Interactions:** Tapping like immediately toggles `currentUserLiked` and adjusts `likeCount` locally, issuing asynchronous network mutation and rolling back on network failure.
- **Cross-Controller Synchronization:** `PostDetailController` mutates and synchronizes state back into `FeedController` for seamless list updates.

---

## Phase 4 — Geospatial Architecture & Nearby Discovery

### Geospatial Stack
- **Database Engine:** PostgreSQL 16 + PostGIS 3.6 spatial extension.
- **Data Type:** `geography(Point, 4326)` for WGS84 ellipsoidal distance calculations in meters (`ST_Distance`, `ST_DWithin`).
- **Spatial Indexing:** GiST index `idx_posts_location_gist` on `posts(location)` ensuring sub-millisecond bounding box lookups even at high data scale.

### Location Privacy Model
1. **Centroid-Based Stamping:** When a post is created, the system maps the author's onboarded locality to an authoritative public locality centroid (e.g., Koramangala centroid: 12.9352° N, 77.6245° E). Posts **never** record or store the author's personal GPS device fix.
2. **Server-Side Distance Computation:** Discovery distances are computed entirely server-side using PostGIS `ST_Distance(location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography)`.
3. **Banded Fuzzy Distance Output:** To prevent triangulation attacks, raw distances are rounded into privacy-safe bands:
   - `< 100m`: `"Nearby"` (rounded to 100m)
   - `100m – 999m`: rounded to nearest 50m (`"${m} m away"`)
   - `1km – 9.9km`: rounded to 1 decimal place (`"${km} km away"`)
   - `10km+`: rounded to nearest integer km (`"${km} km away"`)
4. **Zero Coordinate Exposure:** The `location` column, `latitude`, `longitude`, `author.phone`, and `author.email` are strictly excluded from all API responses.

### Nearby Discovery Controller & State Machine
- **State Machine:** Sealed union `LocationState` (`LocationInitial`, `LocationRequestingPermission`, `LocationPermissionDenied`, `LocationPermissionPermanentlyDenied`, `LocationServiceDisabled`, `LocationAcquiring`, `LocationReady`, `LocationManualLocality`, `LocationError`).
- **Graceful Degradation:** Users who decline GPS permissions can select a manual locality via `LocalityPickerDialog` without sacrificing nearby discovery capabilities.
- **Radius Options:** Validated 1, 3, 5, 10, 20 km options (default 5 km).

---

## Phase 6 — Marketplace Architecture

### Data Models & Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                            User                             │
└──────────────┬──────────────────┬──────────────────┬────────┘
               │ 1 (seller)       │ 1 (reporter)     │ 1
               │                  │                  │
               ▼ *                ▼ *                ▼ *
┌─────────────────────────┐┌──────────────┐┌───────────────────────┐
│   MarketplaceListing    ││ MktReport    ││  MarketplaceFavorite  │
└──────────────┬──────────┘└──────────────┘└───────────────────────┘
               │ 1
               │
               ▼ *
┌─────────────────────────┐
│ MarketplaceListingImage │
└─────────────────────────┘
```

### Architectural Principles:
1. **Zero Raw GPS Exposure**: Listing coordinates always map to locality / neighborhood centroids via spatial registry. Exact seller home addresses and GPS coordinates are never stored or exposed.
2. **Safe Seller Projections**: Endpoints return `SellerProfileDto` (`id`, `displayName`, `avatarUrl`, `locality`, `city`), stripping phone numbers, email addresses, and private metadata.
3. **Hyperlocal PostGIS Indexing**: Listings feature a PostGIS `geography(Point, 4326)` column with a GiST spatial index. `ST_DWithin` and `ST_Distance` provide instant radius discovery and distance calculation.
4. **Resilient Pagination**: Keyset cursor-based pagination prevents offset drift when new listings are added.

---

## Redis Purpose

Redis serves multiple roles:

| Role | Phase |
|---|---|
| Session storage (JWT blocklist) | Phase 2 |
| OTP / rate limiting | Phase 2 |
| Feed caching | Phase 3+ |
| WebSocket pub/sub | Phase 9 |
| Notification queuing | Phase 10 |
| API response caching | Phase 13 |

---

## Admin Dashboard

- **Technology:** Next.js + TypeScript + Tailwind CSS + shadcn/ui
- **Status:** Planned for Phase 12
- **Purpose:** Content moderation, user management, analytics, reports

---

## Security Architecture

- JWT-based authentication (access + refresh tokens)
- Refresh tokens stored in Redis (revocable)
- Access tokens: short-lived (15 minutes)
- Refresh tokens: longer-lived (7 days)
- Never store sensitive tokens in flutter shared preferences — use flutter_secure_storage
- Server validates all client input via NestJS pipes and DTOs
- CORS configured for known origins
- Rate limiting on sensitive endpoints

---

## Localization

The app supports multiple languages. English (en) and Hindi (hi) are the initial languages.

Flutter uses `flutter_localizations` with ARB files:
```
lib/l10n/
├── app_en.arb
└── app_hi.arb
```

Never hardcode user-facing strings in business logic.
