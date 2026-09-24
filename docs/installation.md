# Flutter & Docker Installation Guide

This guide walks through installing Flutter SDK and Docker Desktop on Windows,
which are required to run the Aaspaas project.

---

## 1. Install Flutter SDK (Windows)

### Step 1 — Download Flutter

Download the latest stable Flutter SDK from:
https://docs.flutter.dev/get-started/install/windows/mobile

Or direct download:
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_stable.zip

### Step 2 — Extract

Extract the ZIP to a permanent location. Recommended:

```
C:\flutter
```

> ⚠️ Do NOT place Flutter in `C:\Program Files\` — it requires write permission.

### Step 3 — Add to PATH

1. Press `Win + X` → System → Advanced system settings → Environment Variables
2. Under **User variables**, find `Path` → Edit → New
3. Add: `C:\flutter\bin`
4. Click OK on all dialogs

### Step 4 — Verify

Open a **new** PowerShell window and run:

```powershell
flutter --version
flutter doctor
```

Flutter doctor will report what's missing. Follow its guidance.

### Step 5 — Install Android Studio

Download from: https://developer.android.com/studio

During installation:
- Install Android SDK (API 34+)
- Install Android Emulator
- Accept all SDK licenses

After installation, run:
```powershell
flutter doctor --android-licenses
```

Accept all licenses.

### Step 6 — Create an Android Emulator

1. Open Android Studio
2. More Actions → Virtual Device Manager
3. Create Device → Pixel 7 (or similar) → API 34
4. Start the emulator

---

## 2. Install Docker Desktop (Windows)

### Step 1 — Download

https://www.docker.com/products/docker-desktop/

### Step 2 — Install

Run the installer. During installation:
- Enable WSL 2 backend (recommended)
- Enable "Add Docker to PATH"

### Step 3 — Start Docker Desktop

Launch Docker Desktop from the Start menu. Wait for it to fully start
(the whale icon in the taskbar should stop animating).

### Step 4 — Verify

Open a **new** PowerShell window and run:

```powershell
docker --version
docker compose version
```

---

## 3. Start Aaspaas Development Environment

Once Flutter and Docker are installed:

```powershell
# Navigate to project root
cd "C:\Users\sujee\Desktop\AssPass"

# Start PostgreSQL + Redis
docker compose up -d

# Check services are healthy
docker compose ps

# Start backend
cd backend
npm run start:dev

# In a new terminal, run Flutter
cd ..\mobile
flutter pub get
flutter run
```

---

## 4. Verify Everything Works

### Health Check

```powershell
Invoke-WebRequest -Uri "http://localhost:3000/api/v1/health" | Select-Object -ExpandProperty Content
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

### Swagger UI

Open in browser: http://localhost:3000/api/docs

---

## 5. Troubleshooting

### Flutter not found after adding to PATH
Close and reopen your terminal window. PATH changes require a new session.

### Docker: WSL 2 not found
Install WSL 2 by running in an Administrator PowerShell:
```powershell
wsl --install
```
Then restart your computer.

### Port 5432 already in use
Stop any local PostgreSQL service:
```powershell
Get-Service -Name "postgresql*" | Stop-Service
```

### Port 6379 already in use
Stop any local Redis service or change the Docker port mapping in `docker-compose.yml`.
