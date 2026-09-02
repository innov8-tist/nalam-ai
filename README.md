# Nalam AI Flutter Prototype

Nalam AI is an offline-first rural medical triage prototype. This repository
currently contains only a simple Material 3 interface and integration points;
speech, AI, mapping, and medical functionality are **not implemented yet**.

## Run the app

Install Flutter, connect a device or start an emulator, then run:

```sh
flutter pub get
flutter run
```

For static checks and tests:

```sh
flutter analyze
flutter test
```

## Project structure

```text
lib/
├── main.dart                 # Application entry point
├── app.dart                  # Material app and dark theme
├── core/constants.dart       # Shared strings and constants
├── models/triage_result.dart # Initial triage result model
├── screens/home_screen.dart  # Prototype's single screen
├── widgets/                  # Reusable workspace and feature controls
└── services/                 # Placeholder integration boundaries
```

The future integration points are:

- `services/stt_service.dart` — English and Malayalam speech recognition
- `services/tts_service.dart` — English and Malayalam speech output
- `services/llm_service.dart` — local/optional remote inference and symptom extraction
- `services/map_service.dart` — offline maps, GPS, hospital data, and routing

Each service deliberately throws `UnimplementedError`. The four buttons only
update the workspace message so UI integration can be verified safely.
