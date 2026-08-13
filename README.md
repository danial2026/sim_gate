# SimGate

Self-hosted SMS API Android app. Turns any Android device into a small SMS gateway:
send and manage text messages over a local HTTP API, one app — no carrier services.

## Screenshots

| Grant Permissions | Configure Server (Any) |
| --- | --- |
| ![Permissions](screenshot/01-permissions.png) | ![Configure Server](screenshot/02-configure-server-any.png) |

| Configure Server (WiFi) | SIM Card Selection |
| --- | --- |
| ![Configure Server WiFi](screenshot/03-configure-server-wifi.png) | ![SIM Cards](screenshot/04-sim-cards.png) |

| Server Configuration (Stopped) | Server Configuration (Running) |
| --- | --- |
| ![Server Config - Stopped](screenshot/05-server-config-stopped.png) | ![Server Config - Running](screenshot/08-server-config-running.png) |

| Setting - 1 | Setting - 2 |
| --- | --- |
| ![Setting - 1](screenshot/06-settings-1.png) | ![Setting - 2](screenshot/07-settings-2.png) |

| Dashboard Overview | Dashboard - SMS Activity & Stats |
| --- | --- |
| ![Dashboard](screenshot/09-dashboard.png) | ![Dashboard Stats](screenshot/10-dashboard-stats.png) |

| Swagger UI |
| --- |
| ![Swagger](screenshot/swagger.png) |

## Features

- Embedded HTTP server (shelf) with bearer-token auth and CORS
- Multi-SIM support: detect, activate/deactivate, send via a specific SIM
- Persistent queue with retry/backoff for failed sends
- QR code with the API URL + token for quick client setup
- Built-in Swagger UI docs (`/swagger.html`, gated by a settings toggle)
- Configurable port, IP binding, and log retention (all in-app)
- Server info, request logs, and SMS history (filterable)
- Material UI (dark + light): permissions → server setup → SIM selection → config → API endpoint (QR) → dashboard hub (logs, settings)
- **Runs in the background** while the phone is locked — foreground service with
  persistent notification and wake lock keeps the gateway alive
- **Samsung support** — battery-optimization exemption (Settings → Background
  Service → Fix), opens Device Care battery settings automatically

## Architecture

```
lib/
  constants/   API paths + app-wide constants
  config/      DI container (get_it), theme
  database/    sqflite schema + queries/
  models/      domain models
  repositories/  data access (sms, sim, logs, config)
  services/    business logic (sms send/retry, sims, tokens, platform channel)
  server/      HTTP server, handlers/, middleware/, swagger/
  providers/   ChangeNotifier state for pages
  pages/       UI screens (permissions, setup, sims, config, api endpoint,
               dashboard, logs, settings)
  widgets/     shared widgets
  utils/       helpers, validators, logging
android/app/src/main/kotlin/com/danials/sim_gate/
  MainActivity.kt      app entry (attaches to the process-wide Flutter engine)
  SimGateApplication.kt  owns the persistent engine; keeps the gateway alive
  SimGateService.kt    foreground service (notification + wake lock)
  SimGateChannels.kt   platform channel: sendSms, detectSims, networkInterfaces,
                       foreground service + battery-optimization helpers
```

## Getting started

Requirements: Flutter (stable) + an Android device/emulator with a SIM (or `adb`).

```bash
flutter pub get
flutter run          # pick your device
```

## API

Base URL: `http://<device-ip>:<port>/api` — shown as a QR code in the app.
`GET /health` and the Swagger docs (`/swagger.html`, `/swagger.json`, gated by a
settings toggle) are public; all other endpoints require
`Authorization: Bearer <token>`.

| Method | Path                 | Description                     |
| ------ | -------------------- | ------------------------------- |
| GET    | `/health`            | Liveness check                  |
| GET    | `/swagger.html`      | Swagger UI docs (if enabled)    |
| GET    | `/swagger.json`      | OpenAPI spec (if enabled)       |
| POST   | `/sms/send`          | Queue an SMS: `{recipient, message, simId, maxRetries?, priority?}` |
| POST   | `/sms/cancel`        | Cancel a queued message         |
| GET    | `/sms/status`        | SMS request status              |
| GET    | `/sms/logs`          | SMS history                     |
| GET    | `/sims/active`       | Active SIMs                     |
| POST   | `/sims/activate`     | Activate or deactivate a SIM    |
| GET    | `/server/info`       | Uptime, IP, port, SIMs          |
| GET    | `/server/token`      | Token metadata (generated time) |
| POST   | `/token/regenerate`  | Rotate the token                |
| PUT    | `/config/ip`         | Change bind IP                  |
| PUT    | `/config/port`       | Change bind port                |
| PUT    | `/logs/retention`    | Log retention days and max entries |

## Beszel webhook notifications

Route [Beszel](https://beszel.dev) alerts to a phone via SimGate's SMS API using
a [generic webhook](https://beszel.dev/guide/notifications/generic)
notification. Paste the URL into Beszel **Settings → Notifications**:

```
generic://<phone-ip>:<port>/api/sms/send?template=json&disabletls=yes&$simId=<sim-id>&$recipient=%2B<phone-number>&$priority=high&$maxRetries=3&@authorization=Bearer%20<api-token>
```

Example:

```
generic://192.168.0.119:3000/api/sms/send?template=json&disabletls=yes&$simId=1_2&$recipient=%2B1234567890&$priority=high&@authorization=Bearer%20<your-api-token>
```

How the URL maps to the API:

| URL part                | API field    | Notes |
| ----------------------- | ------------ | ----- |
| `template=json`         | —            | Shoutrrr sends a JSON payload |
| `$simId=<sim-id>`       | `simId`      | Required; `GET /api/sims/active` or the SIM Cards page |
| `$recipient=%2B<num>`   | `recipient`  | Static target; the `+` must be URL-encoded (`%2B`) |
| `$priority=high`        | `priority`   | `low`, `normal`, or `high` |
| `$maxRetries=3`         | `maxRetries` | Optional |
| `@authorization=Bearer%20<token>` | — | Auth header; the space is `%20` |
| `disabletls=yes`        | —            | SimGate serves plain HTTP on the LAN |

The alert title lands in the (ignored) `title` field and the alert message is
sent as the SMS text. The recipient is static — the webhook template can only
inject the alert's title/message dynamically, so changing the target phone
number requires editing the URL.

## Testing

```bash
flutter analyze       # static analysis
flutter test          # unit + widget tests
./scripts/test.sh     # unit/widget/e2e tests
./scripts/check.sh    # full project check (analyze, format, tests, build)
```

## Scripts

| Script               | Purpose                                  |
| -------------------- | ---------------------------------------- |
| `scripts/test.sh`    | Unit, widget, and e2e tests              |
| `scripts/check.sh`   | Analyze, format, tests, Kotlin compile, APK build |
| `scripts/dev.sh`     | Multi-command: analyze, format, run, apk |


## License

[CC BY-NC 4.0](LICENSE) — free to use and modify for non-commercial purposes; no commercial use.

## AI Assistance

Parts of this project were developed with assistance from DeepSeek.
