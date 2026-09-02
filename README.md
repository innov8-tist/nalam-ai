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

Set `SARVAM_API` (or `SARVAM_API_KEY`) in `logic/.env` to enable the voice
button. The app records a mono 16 kHz WAV clip, uploads it to `/transcribe`,
and places Sarvam's transcript in the symptoms text field.

All frontend services use `NALAM_SERVER_URL` from `config.json`. It defaults to
the Android emulator host (`http://10.0.2.2:8000`). Change that one value for
desktop, a physical device, or a deployed server, then run:

```sh
flutter run --dart-define-from-file=config.json
```

For CI or a one-off override, you can still use
`--dart-define=NALAM_SERVER_URL=http://192.168.1.25:8000` instead.

You can also tap the online/offline status bar and change the address once at
runtime; that selection is saved on the device. The connection tester, medical
assessment, and Sarvam transcription all use the selected address. The optional
SmolVLM server URL is derived from the same host using port `8080`.

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
