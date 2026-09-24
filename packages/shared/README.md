# Aaspaas — Shared Packages

This directory is reserved for future shared schemas, API contracts, TypeScript types, and documentation that may be shared across the backend and admin dashboard.

## Planned Contents

- `shared/types/` — Shared TypeScript types/interfaces (e.g., API response shapes)
- `shared/schemas/` — Shared validation schemas (e.g., Zod schemas)
- `shared/constants/` — Shared constants (e.g., error codes, enum values)

## Current Status

Not yet implemented. Added in a later phase when sharing types between packages materially improves developer experience.

## Note on Flutter

Flutter (Dart) cannot directly consume TypeScript packages. The shared package is primarily for the NestJS backend and the Next.js admin dashboard. Any contract shared with Flutter must be manually maintained in Dart as well.
