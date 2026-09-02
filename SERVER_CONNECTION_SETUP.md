# Server connection setup

The frontend has one server setting: `NALAM_SERVER_URL`. Assessment requests,
health checks, Sarvam speech transcription, and the connection-test dialog all
use this address. The optional SmolVLM server uses the same host with port
`8080`.

## Choose the server once

Edit `config.json`:

```json
{
  "NALAM_SERVER_URL": "http://192.168.1.25:8000"
}
```

Then use that configuration whenever you run or build the app:

```sh
flutter run --dart-define-from-file=config.json
```

Common values are:

- Android emulator: `http://10.0.2.2:8000`
- Desktop: `http://127.0.0.1:8000`
- Physical device: `http://YOUR_LAPTOP_WIFI_IP:8000`

No Dart files need to be edited when the IP changes. A CI job can alternatively
pass `--dart-define=NALAM_SERVER_URL=...` directly.

You can alternatively tap the online/offline status bar inside the app, enter
the new complete URL once, and choose **Save & test**. This runtime selection is
stored on the device and takes precedence over the build default.

## Server requirements

Start FastAPI so other devices can reach it:

```sh
cd logic
uvicorn main:app --host 0.0.0.0 --port 8000
```

For voice input, set `SARVAM_API` or `SARVAM_API_KEY` in `logic/.env`. A
physical phone and the server computer must be on the same network, and the
firewall must allow port `8000` (plus `8080` if using the optional model
server).

Verify the configured address from the device browser by opening `/health`,
for example `http://192.168.1.25:8000/health`.
