# 🌌 Aura — Privacy-First Dating App Monorepo

> **India-First MVP · DPDP Act & PIPEDA Compliant · PostGIS Obfuscated Heatmaps · Real-Time Chat**

---

## 📁 Repository Structure

```
E:\Sanjayprojects\Datingapp\
├── docker-compose.yml              # PostgreSQL + PostGIS (v16) + Redis (v7)
├── aura_backend/                   # Node.js + TypeScript Microservices & WebSocket API
│   ├── .env                        # Port, DB credentials, JWT secret, privacy params
│   ├── package.json                # Express, Socket.io, pg, zod, helmet, tsx
│   ├── tsconfig.json               # ES2022 NodeNext TypeScript config
│   ├── prisma/
│   │   └── schema.sql              # 12 tables, PostGIS indexes, obfuscate_to_grid()
│   └── src/
│       ├── server.ts               # HTTP & Socket.io server bootstrap
│       ├── config/db.ts            # PostGIS pool with automatic fallback dev mode
│       └── services/
│           ├── auth/auth.routes.ts # Phone OTP, demo login, JWT issuance
│           ├── location/location.routes.ts # 500m grid obfuscation, radar heatmap, echoes
│           └── chat/chat.socket.ts # Socket.io 1:1 chat, typing indicators, read receipts
│
└── aura_app/                       # Flutter Mobile & Desktop Client (Dart 3.x)
    ├── pubspec.yaml                # flutter_map, socket_io_client, geolocator, etc.
    └── lib/
        ├── main.dart               # Navigation shell with Radar & Chat tabs
        ├── injection_container.dart# GetIt dependency injection setup
        ├── core/
        │   ├── constants/app_colors.dart # Aurora gradient tokens & dark mode colors
        │   └── theme/app_theme.dart      # Material 3 dark theme with custom styling
        ├── shared/widgets/shared_widgets.dart # GlassmorphismCard, AuroraButton, AuroraGradientText
        └── features/
            ├── radar/presentation/screens/radar_screen.dart # Privacy-safe heatmap (zero user pins)
            └── chat/presentation/screens/chat_screen.dart   # Real-time Socket.io chat client
```

---

## 🚀 How to Run

### 1. Start Database & Redis (Optional / Recommended)

If you have Docker Desktop installed, run from the root directory:

```bash
docker compose up -d
```
*Spins up PostgreSQL with PostGIS on port `5432` and Redis on port `6379`, automatically executing `prisma/schema.sql`.*

> **Note:** The backend has a smart mock fallback! Even if Docker/Postgres isn't running, the backend will automatically run in development mode with generated heatmap zones and demo auth.

---

### 2. Run the Backend API & WebSocket Server

Open a terminal and run:

```bash
cd E:\Sanjayprojects\Datingapp\aura_backend
npm run dev
```

You will see:
```text
==================================================
🌌 AURA BACKEND SERVER RUNNING
📡 HTTP API:        http://localhost:3000
⚡ WebSocket / WSS: ws://localhost:3000
❤️  Health Check:    http://localhost:3000/health
==================================================
```

#### Test API Endpoints:
- **Health Check:** `http://localhost:3000/health`
- **Radar Heatmap:** `http://localhost:3000/api/location/radar?lat=19.076&lng=72.8777&radius=25`
- **Echoes (Crossed Paths):** `http://localhost:3000/api/location/echoes`
- **Demo Login:** `POST http://localhost:3000/api/auth/demo-login`

---

### 3. Run the Frontend (Flutter App)

Open a second terminal and run:

```bash
cd E:\Sanjayprojects\Datingapp\aura_app
```

#### Run on Windows Desktop:
```bash
flutter run -d windows
```

#### Run in Chrome Browser:
```bash
flutter run -d chrome
```

#### Run on Android Device / Emulator:
```bash
flutter run
```

---

## 🛡️ Privacy Verification
- **No Individual Coordinates:** Inspect `GET /api/location/radar` — notice that only aggregated density blobs (`densityLevel`, `activityCount`) are returned.
- **500m Grid Rounding:** The `obfuscate_to_grid()` function snaps all raw GPS points to a 500-meter grid cell prior to any database write.
