# Server connection setup

The frontend has one server setting: `NALAM_SERVER_URL`. Assessment requests,
health checks, Sarvam speech transcription, and the connection-test dialog all
use this address. The optional SmolVLM server uses the same host with port
`8080`.

<<<<<<< HEAD
## Choose the server once
=======
Your app is now configured to connect to your laptop server at **10.128.184.195**
>>>>>>> 68255cdb27864337510dfc537594c67fcca33991

Edit `config.json`:

<<<<<<< HEAD
```json
{
  "NALAM_SERVER_URL": "http://192.168.1.25:8000"
}
=======
### 1. SmolVLM2 API Endpoint
**File:** `lib/core/constants.dart`
- Default API URL: `http://10.128.184.195:8080/v1/chat/completions`
- Android Emulator API URL: `http://10.128.184.195:8080/v1/chat/completions`

### 2. Remote AI Service
**File:** `lib/services/remote_ai_service.dart`
- Default base URI: `http://10.128.184.195:8000`

### 3. Android Permissions
**File:** `android/app/src/main/AndroidManifest.xml`
- ✅ INTERNET permission already enabled
- ✅ Cleartext HTTP traffic allowed

## How to Use:

### 1. Start Your Laptop Server
Make sure your server is running on your laptop at:
- AI Service: `http://10.128.184.195:8000`
- SmolVLM2 API: `http://10.128.184.195:8080`

### 2. Connect Your Phone to Same WiFi
- Your phone must be on the same WiFi network as your laptop
- IP: 10.128.184.195

### 3. Run the App
```bash
flutter run
>>>>>>> 68255cdb27864337510dfc537594c67fcca33991
```

Then use that configuration whenever you run or build the app:

<<<<<<< HEAD
```sh
flutter run --dart-define-from-file=config.json
=======
## Verify Connection:

### Test from Phone Browser:
1. Open browser on your phone
2. Visit: `http://10.128.184.195:8000/health`
3. Should see: `{"status": "healthy"}`

### Test from Laptop:
```bash
# Check if server is accessible
curl http://10.128.184.195:8000/health
curl http://10.128.184.195:8080/health
>>>>>>> 68255cdb27864337510dfc537594c67fcca33991
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

<<<<<<< HEAD
## Server requirements

Start FastAPI so other devices can reach it:
=======
**3. Test connection from phone:**
```bash
# From phone's terminal or browser
ping 10.128.184.195
curl http://10.128.184.195:8000/health
```

**4. Check both devices are on same WiFi:**
- Phone WiFi SSID = Laptop WiFi SSID
- Both should be on 10.128.184.x subnet
>>>>>>> 68255cdb27864337510dfc537594c67fcca33991

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
