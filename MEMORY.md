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
│   │   │       ├── 1728300000000-CreatePostMentionsTable.ts
│   │   │       ├── 1728400000000-AddImageSupportToMessages.ts
│   │   │       └── 1728500000000-CreatePostImagesTable.ts
│   │   └── modules/
│   │       ├── auth/                    # JWT authentication, guards, refresh tokens
│   │       ├── users/                   # Identity, usernames, profiles, search
│   │       ├── feed/                    # Posts, @mentions, post images, comments, reactions
│   │       │   ├── dto/                 # create-post.dto, update-post.dto, create-post-image.dto
│   │       │   ├── entities/            # post.entity, post-image.entity, post-mention.entity
│   │       │   └── services/            # feed.service (image validation, sorting & limits)
│   │       ├── media/                   # Image processing, uploads, storage adapters
│   │       ├── messaging/               # Real-time direct conversations & media attachments
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
│   │   │   │   ├── data/models/         # post_model, post_image_model
│   │   │   │   ├── domain/entities/     # post_entity, post_image_entity
│   │   │   │   └── presentation/
│   │   │   │       ├── screens/         # create_post_screen, edit_post_screen, post_detail_screen
│   │   │   │       └── widgets/
│   │   │   │           ├── post_card.dart
│   │   │   │           ├── post_media_carousel.dart
│   │   │   │           └── mentions/    # token parser, autocomplete controller, suggestion panel
│   │   │   ├── shell/                   # Navigation shell, user search, public profiles
│   │   │   └── messaging/               # Chat screens, message bubbles, chat photo viewer
│   │   └── shared/                      # Claymorphic UI kit, avatars, media pickers, gallery viewer
│   │       └── widgets/media/
│   │           ├── app_cached_image.dart
│   │           ├── app_multi_image_picker.dart
│   │           └── app_photo_gallery_viewer.dart
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
- **Authoritative Validation Rule**: The backend loads the user by `userId`, verifies account validity, and asserts that `content.substring(start, start + length).toLowerCase() === '@' + user.username.toLowerCase()`.
- Invalid, mismatched, or out-of-bounds mentions result in `400 Bad Request`.

### 4.2 Database Schema: `post_mentions` Table
- **Migration**: `1728300000000-CreatePostMentionsTable.ts`
- **Columns**: `id`, `post_id`, `mentioned_user_id`, `start`, `length`, `created_at`.
- **Constraints & Indexes**:
  - `CONSTRAINT UQ_post_mentions_post_user_range UNIQUE (post_id, mentioned_user_id, start, length)`
  - `INDEX IDX_post_mentions_post_id (post_id)`
  - `INDEX IDX_post_mentions_mentioned_user_id (mentioned_user_id)`

---

## 5. Media & Image Processing Subsystem

### 5.1 Architecture & Pipeline
- **Service**: `ImageProcessorService`
  - Validates MIME types (JPEG, PNG, WebP) and magic numbers.
  - Automatically strips EXIF metadata for privacy.
  - Generates optimized WebP variants:
    - `thumbnailUrl`: Small square/preview variant for composer grids and thumbnails.
    - `mediumUrl`: Compressed balanced variant for feed cards and chat bubbles.
    - `url` (Standard): High-definition variant for full-screen zoomable viewers.
- **Storage Providers**:
  - `LocalMediaStorageService`: Development and offline storage in local file system with public static serving.
  - `S3MediaStorageService`: Production-ready S3/R2 compatible object storage.
- **Mobile Foundation**:
  - `AppMediaService`: Gallery selection, downscaling, compression, and multipart upload orchestrator.
  - `AppCachedImage`: Robust cached network image loader with shimmer placeholders and error states.

### 5.2 Feed Post Image Attachments Subsystem
- **Image Limit**: **Strictly maximum 4 images per post**, enforced across all layers:
  - Mobile UI (`AppMultiImagePicker` hides Add button when 4 images are selected; shows `4/4`).
  - Mobile Composers (`CreatePostScreen` and `EditPostScreen` validate `<= 4` before submit).
  - Backend DTOs (`CreatePostDto` and `UpdatePostDto` specify `@ArrayMaxSize(4)`).
  - Backend Service (`FeedService.validatePostImages` throws `BadRequestException` if `> 4`).
- **Relational Schema**: `post_images` table (`1728500000000-CreatePostImagesTable.ts`):
  - `id`: UUID Primary Key (`gen_random_uuid()`)
  - `postId`: UUID referencing `posts(id)` with `ON DELETE CASCADE`
  - `url`: Standard image URL (VARCHAR 1024)
  - `thumbnailUrl`: Thumbnail URL (VARCHAR 1024)
  - `mediumUrl`: Medium variant URL (VARCHAR 1024)
  - `width`, `height`, `size`: Numeric dimension and byte size metadata
  - `mimeType`: String (e.g. `image/webp`)
  - `sortOrder`: Smallint (maintains stable user selection ordering)
  - `createdAt`: Timestamp with timezone
  - Indexes: `IDX_post_images_postId`, `IDX_post_images_postId_sortOrder`
- **Presentation Component (`PostMediaCarousel`)**:
  - Displays images in a **single horizontal swipe carousel** using Flutter's native `PageView.builder` with `pageSnapping: true` and `ClampingScrollPhysics`.
  - **Stable Bounded Aspect Ratio**: Uses `ConstrainedBox(maxHeight: 380)` with clamped aspect ratio (`0.8` to `1.78`, defaulting to `4/3`) to guarantee the post card height does not jump during horizontal swipes.
  - **Claymorphic Indicator**:
    - 1 image: Indicator dots and counter badge are hidden.
    - 2 images: Renders `● ○` indicator dots with active width animation and `1/2` badge.
    - 3 images: Renders `● ○ ○` with `1/3` badge.
    - 4 images: Renders `● ○ ○ ○` with `1/4` badge.
  - **Full-Screen Viewer Integration**: Tapping the active carousel image opens `AppPhotoGalleryViewer` starting at that tapped page index.
  - **Legacy Data Safety**: Older posts containing >4 images are rendered safely without data loss, while edits prevent adding new images beyond 4.
- **Full-Screen Gallery Viewer (`AppPhotoGalleryViewer`)**:
  - Full-screen modal with opaque dark backdrop (`AppColors.pureBlack` at 0.95 alpha).
  - Multi-image swipe navigation with `PageView`.
  - Pinch-to-zoom (`InteractiveViewer` with scale 0.5 to 4.0) and double-tap zoom.
  - Page indicator counter ("1 / N") and dismissal close button.

### 5.3 1:1 Direct Messaging Media Attachments
- **Migration**: `1728400000000-AddImageSupportToMessages.ts` adding `media_url`, `media_thumbnail_url`, `media_width`, `media_height`, `media_size`, `media_mime_type` to `messages`.
- **Client Flow**: Auto-compress oversized camera captures to WebP -> multipart upload to `/media/upload` -> send socket message with media URL -> instant local preview in `MessageBubble` with progress overlay and retry -> tap to open full-screen `ChatPhotoViewer`.

---

## 6. Routing, Deep Linking & Navigation

| Route Pattern | Screen / Purpose | Auth Guard |
|---|---|---|
| `/@:username` | `PublicProfileScreen` (Profile view by handle) | Optional / Public |
| `/search/users` | `UserSearchScreen` (User directory search) | Authenticated |
| `/feed` | `HomeScreen` (Geo-feed & discussions) | Authenticated |
| `/post/create` | `CreatePostScreen` (Post composer with @mentions & 4-image picker) | Authenticated |
| `/post/:id` | `PostDetailScreen` (Post card with carousel, comments & mentions) | Authenticated |
| `/conversations` | `ConversationsScreen` (Inbox) | Authenticated |
| `/conversation/:id` | `ConversationScreen` (Direct chat with media attachments) | Authenticated |

---

## 7. Quality Gates & Test Verification

All codebase changes are validated against strict quality thresholds:

### Backend Test Coverage
- **Framework**: Vitest
- **Feed & Mentions**: `test/feed/feed.service.spec.ts` (14 tests), `test/feed/post-mentions.spec.ts` (11 tests), `test/feed/comments.service.spec.ts` (5 tests), `test/feed/reactions.service.spec.ts` (5 tests), `test/feed/reports.service.spec.ts` (3 tests)
- **Users & Handles**: `test/users/users.service.spec.ts` (22 tests), `test/users/users.controller.spec.ts` (7 tests)
- **Messaging**: `test/messaging/messaging.service.spec.ts` (image attachment messaging tests)
- **Verification Commands**:
  ```bash
  cd backend
  npx vitest run test/feed test/messaging   # Status: All tests passing
  npm run build                            # NestJS compilation: 0 errors
  npm run lint                             # ESLint / Oxlint: 0 errors
  ```

### Mobile Test Coverage
- **Framework**: Flutter Test (`flutter_test`)
- **Feed Images & Carousel**: `test/features/feed/post_images_test.dart` (17 tests covering 1, 2, 3, 4 image carousels, dot indicators, swipe advances, viewer open, and 4-image limit enforcement)
- **Feed Widgets & Mentions**: `test/features/feed/feed_widgets_test.dart`, `test/features/feed/mention_autocomplete_test.dart`
- **Messaging Attachments**: `test/features/messaging/messaging_screens_test.dart`
- **Verification Commands**:
  ```bash
  cd mobile
  flutter analyze lib test   # Status: 0 issues found (0 errors, 0 warnings, 0 infos)
  flutter test               # Status: 346/346 tests passing
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
