# Aaspaas — Backend (NestJS)

NestJS REST API for the Aaspaas local community platform.

## Requirements

- Node.js ≥ 20.x LTS
- npm ≥ 10.x
- Docker Desktop (for PostgreSQL + Redis)

## Setup

```bash
# 1. Configure environment
cp .env.example .env

# 2. Start infrastructure services
docker compose up -d   # (run from repository root)

# 3. Install dependencies
npm install

# 4. Run database migrations
npm run migration:run

# 5. Start in development mode
npm run start:dev
```

## API

- Base URL: `http://localhost:3000/api/v1`
- Swagger docs: `http://localhost:3000/api/docs`
- Health check: `GET http://localhost:3000/api/v1/health`

## Commands

```bash
npm run start:dev        # Start with hot reload
npm run build            # TypeScript build
npm run start:prod       # Start built app
npm run lint             # oxlint check
npm run format           # Prettier format
npm run test             # Unit tests (vitest)
npm run test:e2e         # E2E tests
npm run test:cov         # Coverage report

# TypeORM Migrations
npm run migration:generate -- --name=<Name>   # Generate migration
npm run migration:run                          # Apply migrations
npm run migration:revert                       # Revert last migration
npm run migration:show                         # List migrations
```

## Architecture

```
src/
├── config/             # Environment validation
├── common/
│   ├── filters/        # Global HTTP exception filter
│   ├── interceptors/   # Logging + response transform
│   └── (future: guards, pipes, decorators, middleware)
├── database/
│   ├── data-source.ts  # TypeORM CLI data source
│   ├── redis.module.ts # Redis connection (ioredis)
│   ├── redis.service.ts # Redis abstraction
│   └── migrations/     # TypeORM migrations
├── health/             # GET /api/v1/health
├── app.module.ts
└── main.ts
```

## Environment Variables

See `.env.example` for all configurable variables.
