# Aaspaas — Mobile (Flutter)

Flutter application for the Aaspaas local community platform.

## Requirements

- Flutter SDK ≥ 3.24 (stable channel)
- Dart SDK (bundled with Flutter)
- Android Studio + Android SDK (API 34+)

## Install Flutter

Follow the official guide: https://flutter.dev/docs/get-started/install

After installation, add Flutter to your PATH and run:

```bash
flutter doctor
```

Resolve any issues reported before proceeding.

## Setup

```bash
# Install dependencies
flutter pub get

# Verify environment config exists
cp .env.example .env
# (Edit .env if needed — defaults work for Android emulator)
```

## Run

```bash
# Start an Android emulator first (via Android Studio or AVD Manager), then:
flutter run

# Or specify a device explicitly:
flutter devices        # List available devices
flutter run -d <id>   # Run on specific device
```

## Commands

```bash
flutter pub get                              # Install dependencies
flutter run                                  # Run on connected device/emulator
flutter analyze                              # Static analysis
dart format .                                # Format code
flutter test                                 # Run tests
flutter test --coverage                      # Test with coverage

# Code generation (after adding new models/providers)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

# Build
flutter build apk --release                 # Release APK
flutter build appbundle                     # Google Play AAB
```

## Architecture

```
lib/
├── core/
│   ├── config/        # App configuration (AppConfig)
│   ├── constants/     # App constants
│   ├── errors/        # Exception hierarchy
│   ├── network/       # Dio API client with interceptors
│   ├── routing/       # GoRouter configuration
│   ├── storage/       # SecureStorageService + LocalStorageService
│   └── theme/         # Material 3 theme (Phase 1)
│
├── shared/
│   ├── models/        # Shared data models
│   └── widgets/       # Reusable UI components
│
├── features/
│   └── foundation/    # Phase 0 foundation screen
│       (future features added per phase)
│
└── main.dart
```

## Environment Variables

See `.env.example` for all configurable values.

Key variable:
- `API_BASE_URL`: Backend URL — use `http://10.0.2.2:3000/api/v1` for Android emulator.

## Notes

- **Android emulator:** Use `10.0.2.2` instead of `localhost` to reach the host machine.
- **Physical device:** Use your computer's LAN IP address (e.g., `http://192.168.1.x:3000/api/v1`).
