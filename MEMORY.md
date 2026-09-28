# Aaspaas — System Architecture & Memory Bank (`MEMORY.md`)

> **Last Updated**: September 2026  
> **Repository**: [sujeetdon07/AssPass](https://github.com/sujeetdon07/AssPass.git)  
> **Status**: Production-Ready / Active Development

---

## 1. Project Overview & Vision

**Aaspaas** is a hyper-local community platform designed for India, answering the core question: *"What's happening around me?"*  
It brings together neighborhood discussions, geo-anchored feeds, communities, local marketplace, services, events, and real-time messaging.

### Key Technology Stack
- **Mobile Client**: Flutter 3.24+ / Dart (Material 3, Riverpod, GoRouter, Claymorphism Design System, Dio)
- **Backend API**: NestJS 10+ / TypeScript (REST + WebSockets, TypeORM)
- **Primary Data Store**: PostgreSQL 16+ with PostGIS spatial extensions
- **Cache & Realtime**: Redis 7+ (pub/sub, session state, rate limiting)
- **Media Engine**: Sharp (image transcoding/optimization), pluggable storage (Local & AWS S3/Cloudflare R2)

---

## 2. Monorepo Structure

```text
AssPass/
├── backend/                             # NestJS API application
│   ├── src/
│   │   ├── config/                      # Validated environment configuration
│   │   ├── database/                    # TypeORM migrations & naming strategies
│   │   │   └── migrations/
│   │   │       ├── 1728200000000-AddUniqueUsernameToUsers.ts
│   │   │       └── 1728300000000-CreatePostMentionsTable.ts
│   │   └── modules/
│   │       ├── auth/                    # JWT authentication, guards, refresh tokens
│   │       ├── users/                   # Identity, usernames, profiles, search
│   │       ├── feed/                    # Posts, @mentions, comments, reactions
│   │       ├── media/                   # Image processing, uploads, storage adapters
│   │       ├── messaging/               # Real-time direct & group conversations
│   │       ├── communities/             # Neighborhood groups & memberships
│   │       ├── marketplace/             # Local buy/sell listings
│   │       ├── events/                  # Local gatherings & RSVPs
│   │       ├── services/                # Local service directory
│   │       └── notifications/           # Push notifications & deduplication engine
│   └── test/                            # Vitest unit & integration test suites
│
├── mobile/                              # Flutter cross-platform mobile client
│   ├── lib/
│   │   ├── core/                        # Routing (GoRouter), theme, network, services
│   │   │   ├── routing/app_router.dart  # Deep-link routing including /@:username
│   │   │   ├── services/app_media_service.dart
│   │   │   └── services/app_share_service.dart
│   │   ├── features/                    # Feature-first modular architecture
│   │   │   ├── auth/                    # Auth state, login, token management
│   │   │   ├── onboarding/              # Profile setup, handle claim
│   │   │   ├── feed/                    # Feed screen, composer, @mentions, post cards
│   │   │   │   └── presentation/widgets/mentions/
│   │   │   │       ├── mention_token_parser.dart
│   │   │   │       ├── mention_autocomplete_controller.dart
│   │   │   │       ├── mention_suggestion_panel.dart
│   │   │   │       └── mention_text_view.dart
│   │   │   ├── shell/                   # Navigation shell, user search, public profiles
│   │   │   └── messaging/               # Chat screens & active conversations
│   │   └── shared/                      # Claymorphic UI kit, avatars, media pickers
│   └── test/                            # Flutter unit, widget, and controller tests
│
├── docs/                                # Architectural & API documentation
├── docker-compose.yml                   # PostgreSQL + PostGIS + Redis setup
└── MEMORY.md                            # This architectural memory bank
```

---

## 3. Core Architectural Invariants

### 3.1 Three-Tier User Identity Model
Aaspaas enforces a strict separation between internal references, public handles, and display names:

1. **Immutable User ID (`userId`)**:
   - Format: Permanent UUID v4 (e.g., `8d7f2d4e-8b2d-4cf8-9f51-1a2b3c4d5e6f`).
   - Scope: Used for database foreign keys, relational mapping, post ownership, permissions, and mention records.
   - Invariant: **Never changes and is never exposed as an editable identifier.**
2. **Public Username (`@username`)**:
   - Format: Case-insensitive unique handle, 3–30 chars (`[a-zA-Z0-9_.]`).
   - Constraints: Must start/end with alphanumeric, no consecutive periods/underscores, reserved handles prohibited (e.g. `admin`, `support`, `aaspaas`).
   - Scope: Public URLs (`/@:username`), deep links, user search, and post @mentions.
   - Invariant: A user can change their username without breaking post history or relational data.
3. **Display Name (`displayName`)**:
   - User-chosen human name (e.g., "Sujeet Kumar"). Can be changed at any time independently of handle.

---

## 4. Post Mentions & Autocomplete Subsystem

### 4.1 Client-to-Server Contract
When creating or updating posts, the client submits **structured mention metadata**:
```json
{
  "content": "Hey @sujeet and @priya, check this out!",
  "mentions": [
    { "userId": "8d7f2d4e-8b2d-4cf8-9f51-1a2b3c4d5e6f", "start": 4, "length": 7 },
    { "userId": "9a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d", "start": 16, "length": 6 }
  ]
}
```

- `start`: 0-indexed UTF-16 code unit offset where `@` begins.
- `length`: Total UTF-16 character length of the handle token including `@`.
- **Authoritative Validation Rule**: The client **does not** submit usernames as authoritative. The backend loads the user by `userId`, verifies account validity, and asserts that `content.substring(start, start + length).toLowerCase() === '@' + user.username.toLowerCase()`.
- Invalid, mismatched, or out-of-bounds mentions result in `400 Bad Request`.

### 4.2 Database Schema: `post_mentions` Table
- **Migration**: `1728300000000-CreatePostMentionsTable.ts`
- **Columns**:
  - `id`: UUID Primary Key
  - `post_id`: Foreign key referencing `posts(id)` with `ON DELETE CASCADE`
  - `mentioned_user_id`: Foreign key referencing `users(id)` with `ON DELETE CASCADE`
  - `start`: Integer (UTF-16 start offset)
  - `length`: Integer (UTF-16 length)
  - `created_at`: Timestamp with timezone
- **Constraints & Indexes**:
  - `CONSTRAINT UQ_post_mentions_post_user_range UNIQUE (post_id, mentioned_user_id, start, length)`
  - `INDEX IDX_post_mentions_post_id (post_id)`
  - `INDEX IDX_post_mentions_mentioned_user_id (mentioned_user_id)`

### 4.3 Social Notifications Engine
- **Notification Type**: `USER_MENTIONED` (`NotificationCategory.SOCIAL`).
- **Self-Mention Suppression**: Posts where an author mentions themselves are saved to `post_mentions`, but notification dispatch is suppressed (`filter(uid => uid !== authorId)`).
- **Deduplication**: Notifications include an idempotency key: `mention:${postId}:${recipientId}`. Mentioning the same user multiple times in one post triggers only one notification.
- **Update Behavior**: Updating a post removes old mentions and only notifies newly mentioned users.

### 4.4 Mobile Autocomplete & Rendering Architecture
1. **`MentionTokenParser`**:
   - Scans text around cursor selection.
   - Ignores email addresses (ensures `@` is at line start or preceded by whitespace).
   - Extracts current query token (e.g. `@suj` -> `suj`).
2. **`MentionAutocompleteController`**:
   - **Debounce**: 300ms timer suppresses redundant API requests.
   - **Sequence Protection**: Monotonic counter `_requestSequence` discards out-of-order network responses.
   - **Double-Space Prevention**: When inserting `@username `, checks if `text[tokenEnd] == ' '` to prevent double spaces.
   - **Dynamic Text Realignment**: Adjusts offsets of existing mentions when typing or deleting elsewhere in the post. Automatically prunes mention records if the user modifies or backspaces into the mention token.
3. **`MentionSuggestionPanel`**:
   - Claymorphic card overlay displaying search results with `AppAvatar(size: AppAvatarSize.s32)`, display name, and `@username`.
4. **`MentionTextView`**:
   - Formats post text into clickable `TextSpan` elements.
   - Valid mentions are rendered in the primary brand color with semibold styling and navigate to `/@:username` on tap.

---

## 5. Media & Image Processing Subsystem

### 5.1 Architecture
- **Service**: `ImageProcessorService`
  - Validates MIME types (JPEG, PNG, WebP) and magic numbers.
  - Automatically strips EXIF metadata for privacy.
  - Generates optimized WebP and JPEG variants, standard avatars (256x256), and feed thumbnails.
- **Storage Providers**:
  - `LocalMediaStorageService`: Development and offline storage in local file system with public static serving.
  - `S3MediaStorageService`: Production-ready S3/R2 compatible object storage.
- **Mobile Integration**:
  - `AppMediaService`: Image capture, gallery selection, compression, and upload orchestrator.
  - `AppAvatarPicker`: One-tap avatar picker with square-crop modal (`AppSquareCropDialog`).
  - `AppCachedImage`: Robust image loader with shimmer placeholders and fallback avatars.

---

## 6. Routing, Deep Linking & Navigation

| Route Pattern | Screen / Purpose | Auth Guard |
|---|---|---|
| `/@:username` | `PublicProfileScreen` (Profile view by handle) | Optional / Public |
| `/search/users` | `UserSearchScreen` (User directory search) | Authenticated |
| `/feed` | `HomeScreen` (Geo-feed & discussions) | Authenticated |
| `/post/create` | `CreatePostScreen` (Post composer with @mentions) | Authenticated |
| `/post/:id` | `PostDetailScreen` (Post, comments & mentions) | Authenticated |
| `/conversations` | `ConversationsScreen` (Inbox) | Authenticated |
| `/conversation/:id` | `ConversationScreen` (Direct chat) | Authenticated |

---

## 7. Quality Gates & Test Verification

All codebase changes are validated against strict quality thresholds:

### Backend Test Coverage
- **Framework**: Vitest
- **Feed & Mentions**: `test/feed/post-mentions.spec.ts` (11 tests), `test/feed/feed.service.spec.ts` (8 tests)
- **Users & Handles**: `test/users/users.service.spec.ts` (22 tests), `test/users/users.controller.spec.ts` (7 tests)
- **Media Processing**: `test/media/media.spec.ts`
- **Verification Command**:
  ```bash
  cd backend && npx vitest run test/feed test/users
  # Status: 61/61 tests passing
  npm run build   # NestJS compilation: 0 errors
  npm run lint    # ESLint / Oxlint: 0 errors
  ```

### Mobile Test Coverage
- **Framework**: Flutter Test (`flutter_test`)
- **Mention Autocomplete**: `test/features/feed/mention_autocomplete_test.dart` (15 tests)
- **Media & Share**: `test/core/services/app_share_service_test.dart`, `test/core/services/app_media_service_test.dart`
- **Auth & Profiles**: `test/features/auth/username_test.dart`
- **Verification Command**:
  ```bash
  cd mobile
  flutter analyze lib test   # Status: 0 issues found
  flutter test               # Status: 328/328 tests passing
  ```

---

## 8. Operational & Developer Runbook

### Starting Local Services
```bash
# 1. Start PostgreSQL (with PostGIS) and Redis
docker compose up -d

# 2. Run Backend Migrations & Dev Server
cd backend
npm run migration:run
npm run start:dev

# 3. Run Mobile App
cd mobile
flutter pub get
flutter run
```

### Git & Branch Invariants
- All production changes merge into `main`.
- Remote origin: `https://github.com/sujeetdon07/AssPass.git`.
- Clean working directory with no untracked secrets or temporary build artifacts.
