# Nalam AI Flutter Prototype

Nalam AI is an offline-first rural medical triage prototype. It prefers the
more capable Python server while it is reachable and automatically falls back
to the on-device SmolVLM2 model when the server is unavailable.

## Run the app

Install Flutter, connect a device or start an emulator, then run:

```sh
flutter pub get
flutter run
```

Start the API from `logic/` with its environment variables configured:

```sh
uvicorn main:app --host 0.0.0.0 --port 8000
```

The Android emulator connects to `http://10.0.2.2:8000` by default. Desktop
builds use `http://127.0.0.1:8000`. For a physical device or deployed server,
set the address at build/run time:

```sh
flutter run --dart-define=NALAM_API_BASE_URL=https://api.example.com
```

The app checks `/health` every 20 seconds. A successful health check displays
the online indicator and routes text/image assessment requests to `/chat`.
Failed server requests immediately retry with the local model when it is ready.
Tap the online/offline indicator to change and test the server address at
runtime. A physical phone must use the laptop's LAN address, not `10.0.2.2`.

For static checks and tests:

```sh
flutter analyze
flutter test
```

## Project structure

```text
lib/
├── main.dart                 # Application entry point
├── app.dart                  # Material app and connectivity indicator
├── core/constants.dart       # Shared strings and constants
├── models/triage_result.dart # Initial triage result model
├── screens/                  # Assessment, care, monitoring, and profile UI
├── widgets/                  # Reusable workspace and feature controls
└── services/                 # Placeholder integration boundaries
```

Other integration points include:

- `services/stt_service.dart` — English and Malayalam speech recognition
- `services/tts_service.dart` — English and Malayalam speech output
- `services/llm_service.dart` — local SmolVLM2 inference
- `services/remote_ai_service.dart` — Python server health and inference client
- `services/map_service.dart` — offline maps, GPS, hospital data, and routing
