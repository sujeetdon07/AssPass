# Aaspaas — Development Guide

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | ≥ 3.24 (stable) | [Install guide](https://flutter.dev/docs/get-started/install) |
| Dart | Bundled with Flutter | — |
| Android Studio | Latest stable | For Android emulator & SDK |
| Android SDK | API 34+ | Install via Android Studio |
| Node.js | ≥ 20.x LTS | [nodejs.org](https://nodejs.org) |
| npm | ≥ 10.x | Bundled with Node.js |
| Docker Desktop | Latest stable | [docker.com](https://www.docker.com/products/docker-desktop) |
| Git | ≥ 2.x | [git-scm.com](https://git-scm.com) |

---

## First-Time Setup

### 1. Clone the repo

```bash
git clone https://github.com/your-org/aaspaas.git
cd aaspaas
```

### 2. Copy environment files

```bash
# Backend environment
cp backend/.env.example backend/.env
```

Edit `backend/.env` to verify the values match your Docker setup. The defaults are pre-filled for local Docker development.

For Flutter:
```bash
cp mobile/.env.example mobile/.env
```

### 3. Start infrastructure services

```bash
docker compose up -d
```

Check that both services are healthy:

```bash
docker compose ps
```

Both `aaspaas_postgres` and `aaspaas_redis` should show `healthy`.

### 4. Install backend dependencies

```bash
cd backend
npm install
```

### 5. Run database migrations

```bash
cd backend
npm run migration:run
```

### 6. Start the backend in development mode

```bash
cd backend
npm run start:dev
```

The API will be available at: `http://localhost:3000`

### 7. Verify the health endpoint

```bash
curl http://localhost:3000/api/v1/health
```

### 8. Open Swagger docs

Navigate to: [http://localhost:3000/api/docs](http://localhost:3000/api/docs)

### 9. Install Flutter dependencies

```bash
cd mobile
flutter pub get
```

### 10. Run the Flutter app

```bash
cd mobile
flutter run
```

Ensure an Android emulator is running or a physical device is connected.

---

## Environment Variables

### Backend (`backend/.env`)

| Variable | Description | Default (local dev) |
|---|---|---|
| `NODE_ENV` | Runtime environment | `development` |
| `PORT` | API server port | `3000` |
| `DATABASE_URL` | PostgreSQL connection string | See `.env.example` |
| `REDIS_HOST` | Redis hostname | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |
| `REDIS_PASSWORD` | Redis password | `aaspaas_redis_dev_password` |
| `JWT_ACCESS_SECRET` | JWT signing secret | Must be set |
| `JWT_REFRESH_SECRET` | JWT refresh signing secret | Must be set |

> **Production:** Use strong random secrets. Never use the development defaults in production.

### Flutter (`mobile/.env`)

| Variable | Description | Default |
|---|---|---|
| `API_BASE_URL` | Backend API base URL | `http://10.0.2.2:3000/api/v1` |
| `ENVIRONMENT` | App environment | `development` |

> **Note:** `10.0.2.2` is the Android emulator's loopback address for the host machine's localhost.

---

## Development Commands

### Backend

```bash
# Development (hot reload)
npm run start:dev

# Production build
npm run build

# Start built production app
npm run start:prod

# Linting
npm run lint
npm run lint:fix

# Formatting
npm run format

# Testing
npm run test              # Unit tests
npm run test:watch        # Watch mode
npm run test:cov          # Coverage report
npm run test:e2e          # E2E tests

# Database migrations (TypeORM)
npm run migration:generate -- --name=<MigrationName>
npm run migration:run
npm run migration:revert
npm run migration:show    # Show pending migrations
```

### Flutter

```bash
# Install / update dependencies
flutter pub get

# Run in debug mode
flutter run

# Run on specific device
flutter run -d <device-id>
flutter devices           # List available devices

# Static analysis
flutter analyze

# Format code
dart format .

# Tests
flutter test
flutter test --coverage

# Code generation (freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

# Build
flutter build apk          # Debug APK
flutter build apk --release # Release APK
flutter build appbundle    # Release AAB (Play Store)
```

### Docker

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Stop and remove volumes (⚠️ deletes all local data)
docker compose down -v

# View logs
docker compose logs -f
docker compose logs -f postgres
docker compose logs -f redis

# Status
docker compose ps

# Connect to PostgreSQL
docker exec -it aaspaas_postgres psql -U aaspaas -d aaspaas_db

# Connect to Redis CLI
docker exec -it aaspaas_redis redis-cli -a aaspaas_redis_dev_password
```

---

## Code Quality Standards

### Backend

- TypeScript strict mode (`strict: true` in tsconfig)
- ESLint with NestJS recommended rules
- Prettier formatting
- No `any` types without documented justification
- All DTOs validated with class-validator
- All services have unit tests

### Flutter

- `flutter analyze` must pass with zero errors
- `dart format .` applied before commits
- Strong typing — no unnecessary `dynamic`
- All reusable widgets extracted to `shared/widgets/`
- No hardcoded user-facing strings (use l10n)

---

---

## Phase 2: Local Authentication & Onboarding Development

### Testing Phone & OTP Flow Locally

In development mode (`NODE_ENV=development`), the backend uses `DevelopmentOtpProvider` which returns the generated OTP challenge directly in the API response as `devOtp`:

1. **Request OTP**:
   ```bash
   curl -X POST http://localhost:3000/api/v1/auth/otp/request \
     -H "Content-Type: application/json" \
     -d '{"phoneNumber": "+919876543210"}'
   ```
   *Response includes `devOtp: "XXXXXX"` alongside `maskedPhoneNumber`.*

2. **Verify OTP**:
   ```bash
   curl -X POST http://localhost:3000/api/v1/auth/otp/verify \
     -H "Content-Type: application/json" \
     -d '{"phoneNumber": "+919876543210", "otp": "XXXXXX"}'
   ```
   *Response includes `accessToken`, `refreshToken`, and `user` object.*

3. **Complete Onboarding**:
   ```bash
   curl -X PATCH http://localhost:3000/api/v1/users/me/onboarding \
     -H "Authorization: Bearer <accessToken>" \
     -H "Content-Type: application/json" \
     -d '{
       "displayName": "Sujeet Sharma",
       "city": "Bengaluru",
       "locality": "Indiranagar",
       "state": "Karnataka",
       "countryCode": "IN"
     }'
   ```

### Mobile App OTP Experience in Development
- In debug/development mode, when an OTP is requested, the mobile screen displays a helpful chip with the `devOtp` code.
- Tapping the `devOtp` chip automatically fills the 6-digit PIN input fields for frictionless development testing.

---

## Phase 3: Community Feed Development

### Database Migrations for Community Feed

Phase 3 introduces the `posts`, `post_reactions`, `comments`, and `reports` tables with composite unique constraints and enum types.

Apply the migration:
```bash
cd backend
npm run migration:run
```

Migration file: `backend/src/database/migrations/1727100000000-CreateFeedTables.ts`

### Testing Community Feed Locally

1. **Create a Post** (locality is automatically inherited from the author's onboarding profile):
   ```bash
   curl -X POST http://localhost:3000/api/v1/feed/posts \
     -H "Authorization: Bearer <accessToken>" \
     -H "Content-Type: application/json" \
     -d '{
       "content": "Power outage in 4th block since 3 PM. Anyone else experiencing this?",
       "category": "alert"
     }'
   ```

2. **Fetch Feed with Cursor Pagination**:
   ```bash
   curl -X GET "http://localhost:3000/api/v1/feed?limit=10" \
     -H "Authorization: Bearer <accessToken>"
   ```

3. **Toggle Like** (idempotent toggle):
   ```bash
   curl -X POST http://localhost:3000/api/v1/feed/posts/<postId>/like \
     -H "Authorization: Bearer <accessToken>"
   ```

4. **Add Comment**:
   ```bash
   curl -X POST http://localhost:3000/api/v1/feed/posts/<postId>/comments \
     -H "Authorization: Bearer <accessToken>" \
     -H "Content-Type: application/json" \
     -d '{"content": "Yes, BESCOM says power should be back by 6 PM."}'
   ```

5. **Report Content (Trust & Safety)**:
   ```bash
   curl -X POST http://localhost:3000/api/v1/feed/reports \
     -H "Authorization: Bearer <accessToken>" \
     -H "Content-Type: application/json" \
     -d '{
       "targetType": "post",
       "targetId": "<postId>",
       "reason": "misinformation",
       "details": "Power is actually restored."
     }'
   ```

### Live Feed Runtime Verification Script

A standalone automated runtime verification script is provided to test the live API against PostgreSQL and Redis:

```bash
cd backend
node test-feed-runtime.mjs
```

This verifies:
- PostgreSQL & Redis connectivity (`GET /api/v1/health`)
- Dual-user authentication and onboarding
- Post creation with inherited locality and coordinate privacy
- Locality-scoped and category-filtered feed queries
- Idempotent like/unlike toggling with transactional counters
- Comments thread listing and counter synchronization
- Ownership authorization: `403 Forbidden` on unauthorized comment/post edits and deletes
- Authorized comment/post updates and soft deletes (`204 No Content`)
- Trust & Safety reporting (`200 OK`) and duplicate report rejection (`409 Conflict`)
- Soft-deleted post isolation (`404 Not Found`)

---

## Testing Strategy

---

## Phase 4: Nearby Discovery Development

### Database Migration for PostGIS Spatial Support

Phase 4 enables PostGIS 3.6 on PostgreSQL and adds a spatial `location geography(Point, 4326)` column with a GiST spatial index to `posts`.

Apply the migration:
```bash
cd backend
npm run migration:run
```

Migration file: `backend/src/database/migrations/1727200000000-AddSpatialLocationToPosts.ts`

### Testing Nearby Discovery Locally

1. **Query Nearby Posts within 5 km** (default):
   ```bash
   curl -X GET "http://localhost:3000/api/v1/nearby/posts?latitude=12.9352&longitude=77.6245&radius=5" \
     -H "Authorization: Bearer <accessToken>"
   ```

2. **Query with Custom Radius and Category Filter**:
   ```bash
   curl -X GET "http://localhost:3000/api/v1/nearby/posts?latitude=12.9352&longitude=77.6245&radius=10&category=alert" \
     -H "Authorization: Bearer <accessToken>"
   ```

3. **Run End-to-End Live Verification Script**:
   ```bash
   cd backend
   node test-nearby-runtime.mjs
   ```
   *Verifies multi-locality centroid post creation, spatial radius boundary filtering (1km vs 10km), distance formatting bands, zero raw coordinate exposure, input validation boundaries, and unauthenticated rejections.*

---

## Testing

### Backend Tests

Run unit tests:
```bash
cd backend
npm run test
```
The test suite covers (72 tests across 14 test files):
- `HealthService` — verifies database and Redis connectivity.
- `PhoneNumberUtil` — tests E.164 normalization, validation, and privacy masking (`+91 ••••••3210`).
- `TokenService` — tests RFC 7519 HMAC-SHA256 JWT signing, token expiry, payload verification, and constant-time refresh token comparison.
- `OtpService` — tests 6-digit challenge generation, cryptographic hashing, cooldown enforcement, rate limiting, and attempt exhaustion.
- `AuthService` — tests end-to-end OTP request, verification, session creation, token rotation, and logout revocation.
- `LocalitiesService` — tests locality prefix searching, city filtering, and Indian geography fixture handling.
- `FeedService` — tests post creation with inherited locality centroid stamping, cursor pagination, category filtering, own post edits/deletions, ownership checks, and 404/403 guard rails.
- `ReactionsService` — tests like/unlike toggling, database transaction counter management, and user like states.
- `CommentsService` — tests comment creation, chronological listing, counter synchronization, and author-only soft deletion.
- `ReportsService` — tests content reporting, duplicate report conflict prevention, and target validation.
- `FeedController` — tests controller route delegation, status codes, and DTO handling.
- `NearbyDto` — tests validation of latitude, longitude, radius options (1, 3, 5, 10, 20 km), limits, and distance formatting bands.
- `NearbyService` — tests PostGIS spatial queries, distance calculations, cursor pagination, and rate limiting.
- `NearbyController` — tests nearby route delegation, query parameter parsing, and response envelope.

Run E2E tests (requires running PostgreSQL + Redis):
```bash
cd backend
npm run test:e2e
```

### Flutter Tests

Run all unit and widget tests:
```bash
cd mobile
flutter test
```
The test suite covers (134 tests across 18 test files):
- `theme_test.dart` — Design tokens (colors, typography, spacing, radius, elevations, icons).
- `components_test.dart` — Design system reusable components (buttons, cards, chips, badges, avatars, inputs).
- `widget_test.dart` — Startup, app shell navigation across all 5 tabs (including Nearby Discovery and Marketplace), theme switching, foundation screen route preservation.
- `auth_controller_test.dart` — Riverpod auth state transitions (`AuthUnauthenticated`, `AuthAuthenticated`, `AuthOnboardingRequired`), secure token persistence.
- `onboarding_controller_test.dart` — Multi-step onboarding form state mutations and submission.
- `auth_screens_test.dart` — UI widget tests for WelcomeScreen, PhoneInputScreen, and OtpVerificationScreen (including OtpPinInput).
- `onboarding_screens_test.dart` — UI widget tests for ProfileSetupScreen and CompletionScreen.
- `feed_controller_test.dart` — Community feed state management, cursor pagination, category filtering, optimistic like toggling, and feed post creation.
- `post_detail_controller_test.dart` — Post detail loading, optimistic likes, comment creation, and comment soft deletion.
- `feed_widgets_test.dart` — PostCard rendering, category badges, like button toggle interaction, and ReportContentDialog form & submission.
- `feed_screens_test.dart` — CreatePostScreen form validation & submission, PostDetailScreen comments list & comment input bar.
- `location_controller_test.dart` — Location state transitions (initial, service disabled, permission denied, permanently denied, ready, manual locality, settings navigation).
- `nearby_controller_test.dart` — Nearby posts loading, cursor pagination, radius switching, category filtering, and optimistic like toggling with rollback.
- `nearby_widgets_test.dart` — UI widget tests for RadiusSelector, LocationHeaderBadge, and NearbyPermissionView handling all permission and fallback states.
- `communities_models_test.dart` — Community models, categories, membership models, and pagination.
- `communities_controller_test.dart` — Community controller state, join/leave actions, and categories.
- `communities_screens_test.dart` — Community card rendering and widgets.
- `marketplace_models_test.dart` — Marketplace category, condition, status, price formatting, and pagination models.
- `marketplace_controller_test.dart` — Marketplace discovery, search query, category filters, and optimistic favorites.
- `marketplace_screens_test.dart` — ListingCard rendering, condition chips, status chips, free giveaway badges, sold overlays, and filter bottom sheet interactions.

### Automated End-to-End Runtime Verification

Run the comprehensive Phase 6 backend verification script:
```bash
cd backend
node scripts/verify-phase6.mjs
```
Validates:
1. Infrastructure health (PostgreSQL + Redis).
2. Authenticates test seller and buyer.
3. Listing creation with media image metadata and locality centroid resolution.
4. Privacy-safe projections (zero phone, email, or exact coordinate exposure).
5. Listing detail retrieval and ownership flags.
6. Category, price range, free giveaway, and PostGIS 5 km spatial radius searches.
7. Optimistic favorite/unfavorite toggle flows and count consistency.
8. Trust & safety reports and duplicate report prevention (409 Conflict).
9. Owner status updates (`active` -> `sold`).
10. Authorization boundaries (unauthorized edit/delete rejection with 403 Forbidden).
11. Owner edit and soft deletion (404 for deleted items).
12. Zero regressions across Phase 2 (Auth), Phase 3 (Feed), Phase 4 (Nearby), and Phase 5 (Communities).

## Database

### Local Connection Details

| Setting | Value |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| Database | `aaspaas_db` |
| User | `aaspaas` |
| Password | `aaspaas_dev_password` |

Connection string:
```
postgresql://aaspaas:aaspaas_dev_password@localhost:5432/aaspaas_db
```

### Migrations

Migrations live in: `backend/src/database/migrations/`

Generate a new migration after making entity changes:
```bash
cd backend
npm run migration:generate -- --name=DescriptiveMigrationName
```

Apply all pending migrations:
```bash
npm run migration:run
```

---

## Troubleshooting

### Docker services not starting

Check if ports 5432 or 6379 are already in use:
```bash
# Windows
netstat -ano | findstr :5432
netstat -ano | findstr :6379
```

Stop conflicting services or change the Docker port mappings in `docker-compose.yml`.

### Health endpoint returns `database: "disconnected"`

1. Verify Docker is running: `docker compose ps`
2. Check PostgreSQL logs: `docker compose logs postgres`
3. Verify `DATABASE_URL` in `backend/.env` matches the Docker service credentials

### Flutter build errors after adding packages

```bash
cd mobile
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Android emulator cannot reach backend

Use `10.0.2.2` instead of `localhost` or `127.0.0.1` in `API_BASE_URL` for Android emulator.
