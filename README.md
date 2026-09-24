# Aaspaas

> **Your Local World, In One App.**

Aaspaas is a modern local community platform designed for India, built to connect people with everything relevant to their local area — communities, discussions, businesses, services, events, marketplace listings, and much more.

---

## What It Is

Aaspaas answers the core question:

> _"What's happening around me?"_

Users can connect with nearby people, join local communities, discover local discussions, report local issues, find lost/found items, buy and sell locally, discover local events, and interact with nearby businesses and service providers.

---

## Technology Stack

| Layer | Technology |
|---|---|
| **Mobile** | Flutter + Dart (Material 3, Riverpod, GoRouter, Dio) |
| **Backend** | NestJS + TypeScript (REST + WebSockets) |
| **Database** | PostgreSQL + PostGIS |
| **Cache / Realtime** | Redis |
| **Admin Dashboard** | Next.js + Tailwind CSS + shadcn/ui *(planned — Phase 12)* |
| **Push Notifications** | Firebase Cloud Messaging *(planned)* |
| **Maps** | Google Maps Platform *(planned)* |
| **Media Storage** | AWS S3 / Cloudflare R2 *(planned)* |

---

## Repository Structure

```
aaspaas/
├── mobile/          # Flutter application (Android-first, iOS-compatible)
├── backend/         # NestJS REST API
├── admin/           # Future Next.js admin dashboard (Phase 12)
├── packages/
│   └── shared/      # Future shared schemas and API contracts
├── docs/
│   ├── architecture.md
│   ├── development.md
│   └── api.md
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md        # This file
```

---

## Requirements

Before setting up, ensure the following tools are installed:

| Tool | Required Version | Installation |
|---|---|---|
| **Flutter SDK** | ≥ 3.24.x (stable) | [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) |
| **Dart** | Bundled with Flutter | — |
| **Node.js** | ≥ 20.x LTS | [nodejs.org](https://nodejs.org) |
| **npm** | ≥ 10.x | Bundled with Node.js |
| **Docker Desktop** | Latest stable | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) |
| **Git** | ≥ 2.x | [git-scm.com](https://git-scm.com) |

> **Android development:** Android Studio + Android SDK (API 34+) required for Flutter mobile development.

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/your-org/aaspaas.git
cd aaspaas
```

### 2. Configure environment variables

```bash
# Root (documents top-level settings)
cp .env.example .env

# Backend
cp backend/.env.example backend/.env
# Edit backend/.env with your local settings

# Mobile
cp mobile/.env.example mobile/.env
```

### 3. Start Docker services (PostgreSQL + Redis)

```bash
docker compose up -d
```

Verify services are running:

```bash
docker compose ps
```

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

### 6. Start the backend

```bash
cd backend
npm run start:dev
```

Backend will be available at: `http://localhost:3000`

### 7. Access API documentation (Swagger)

Open in browser: [http://localhost:3000/api/docs](http://localhost:3000/api/docs)

### 8. Check health endpoint

```bash
curl http://localhost:3000/api/v1/health
```

Expected response:

```json
{
  "success": true,
  "service": "aaspaas-api",
  "environment": "development",
  "database": "connected",
  "redis": "connected"
}
```

### 9. Set up Flutter

```bash
cd mobile
flutter pub get
flutter run
```

> Ensure an Android device or emulator is connected/running before `flutter run`.

---

## Development Commands

### Backend

```bash
cd backend

npm run start:dev        # Start with hot reload
npm run build            # Production build
npm run lint             # ESLint check
npm run lint:fix         # ESLint auto-fix
npm run format           # Prettier format
npm run test             # Unit tests
npm run test:e2e         # End-to-end tests
npm run migration:generate -- --name=MigrationName   # Generate migration
npm run migration:run    # Run pending migrations
npm run migration:revert # Revert last migration
```

### Flutter

```bash
cd mobile

flutter pub get          # Install dependencies
flutter run              # Run on connected device
flutter analyze          # Static analysis
dart format .            # Format code
flutter test             # Unit tests
flutter build apk        # Build APK (release)
```

### Docker

```bash
docker compose up -d     # Start all services in background
docker compose down      # Stop all services
docker compose logs -f   # Follow logs
docker compose ps        # Check service status
```

---

## Documentation

- [Architecture Overview](docs/architecture.md)
- [Development Guide](docs/development.md)
- [API Reference](docs/api.md)

---

## Phase Roadmap

| Phase | Description | Status |
|---|---|---|
| Phase 0 | Project Foundation | ✅ In Progress |
| Phase 1 | Design System & App Shell | ⏳ Planned |
| Phase 2 | Authentication & Onboarding | ⏳ Planned |
| Phase 3 | Community Feed | ⏳ Planned |
| Phase 4 | Nearby & Maps | ⏳ Planned |
| Phase 5 | Communities | ⏳ Planned |
| Phase 6 | Marketplace | ⏳ Planned |
| Phase 7 | Businesses & Services | ⏳ Planned |
| Phase 8 | Events | ⏳ Planned |
| Phase 9 | Messaging | ⏳ Planned |
| Phase 10 | Notifications | ⏳ Planned |
| Phase 11 | Trust & Safety | ⏳ Planned |
| Phase 12 | Admin Dashboard | ⏳ Planned |
| Phase 13 | Performance & Scale | ⏳ Planned |
| Phase 14 | Production Launch | ⏳ Planned |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
