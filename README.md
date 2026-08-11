# SimGate

Self-hosted SMS API Android app. Turns any Android device into a small SMS gateway:
send and manage text messages over a local HTTP API, one app — no carrier services.

## Features

- Embedded HTTP server (shelf) with bearer-token auth and CORS
- Multi-SIM support: detect, activate/deactivate, send via a specific SIM
- Persistent queue with retry/backoff for failed sends
- QR code with the API URL + token for quick client setup
- Configurable port, IP binding, and log retention (all in-app)
- Server info, request logs, and SMS history (filterable)
- Material dark UI with a simple 4-page flow (permissions → dashboard → settings → SIMs)

## Architecture

```
lib/
  constants/   shared constants (API paths)
  config/      DI container (get_it), theme
  database/    sqflite schema + queries
  models/      domain models
  repositories/  data access (sms, sim, logs)
  services/    business logic (sms send/retry, config, tokens)
  server/      HTTP server, handlers, middleware
  providers/   ChangeNotifier state for pages
  pages/       UI screens
  widgets/     shared widgets
android/app/src/main/kotlin/com/example/sim_gate/
  SimGateChannels.kt   platform channel: sendSms, detectSims, networkInterfaces
```

## Getting started

Requirements: Flutter (stable) + an Android device/emulator with a SIM (or `adb`).

```bash
flutter pub get
flutter run          # pick your device
```

## API

Base URL: `http://<device-ip>:<port>/api` — shown as a QR code in the app.
All endpoints except `GET /health` require `Authorization: Bearer <token>`.

| Method | Path                 | Description                     |
| ------ | -------------------- | ------------------------------- |
| GET    | `/health`            | Liveness check                  |
| POST   | `/sms/send`          | Queue an SMS: `{recipient, message, simId?}` |
| POST   | `/sms/cancel`        | Cancel a queued message         |
| GET    | `/sms/status`        | SMS request status              |
| GET    | `/sms/logs`          | SMS history                     |
| GET    | `/sims/active`       | Active SIMs                     |
| POST   | `/sims/activate`     | Activate a SIM                  |
| GET    | `/server/info`       | Uptime, IP, port, SIMs          |
| GET    | `/server/token`      | Current token                   |
| POST   | `/token/regenerate`  | Rotate the token                |
| PUT    | `/config/ip`         | Change bind IP                  |
| PUT    | `/config/port`       | Change bind port                |
| PUT    | `/logs/retention`    | Log retention days              |

## Testing

```bash
flutter analyze       # static analysis
flutter test          # unit + widget tests
./scripts/test.sh     # analyze + full test suite
./scripts/check.sh    # full project check (analyze, tests, build)
```

## Scripts

| Script               | Purpose                                  |
| -------------------- | ---------------------------------------- |
| `scripts/test.sh`    | Analyze + unit/widget tests              |
| `scripts/check.sh`   | Full check: analyze, tests, APK build    |
| `scripts/dev.sh`     | Run the app on a connected device        |
