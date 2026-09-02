# Server Connection Setup

## Configuration Complete ✅

Your app is now configured to connect to your laptop server at **172.20.10.9**

## What Was Changed:

### 1. SmolVLM2 API Endpoint
**File:** `lib/core/constants.dart`
- Default API URL: `http://172.20.10.9:8080/v1/chat/completions`
- Android Emulator API URL: `http://172.20.10.9:8080/v1/chat/completions`

### 2. Remote AI Service
**File:** `lib/services/remote_ai_service.dart`
- Default base URI: `http://172.20.10.9:8000`

### 3. Android Permissions
**File:** `android/app/src/main/AndroidManifest.xml`
- ✅ INTERNET permission already enabled
- ✅ Cleartext HTTP traffic allowed

## How to Use:

### 1. Start Your Laptop Server
Make sure your server is running on your laptop at:
- AI Service: `http://172.20.10.9:8000`
- SmolVLM2 API: `http://172.20.10.9:8080`

### 2. Connect Your Phone to Same WiFi
- Your phone must be on the same WiFi network as your laptop
- IP: 172.20.10.9

### 3. Run the App
```bash
flutter run
```

The app will automatically connect to your laptop server.

## Verify Connection:

### Test from Phone Browser:
1. Open browser on your phone
2. Visit: `http://172.20.10.9:8000/health`
3. Should see: `{"status": "healthy"}`

### Test from Laptop:
```bash
# Check if server is accessible
curl http://172.20.10.9:8000/health
curl http://172.20.10.9:8080/health
```

## Troubleshooting:

### App can't connect to server

**1. Check firewall on laptop:**
```bash
# Allow port 8000 and 8080
sudo ufw allow 8000
sudo ufw allow 8080
```

**2. Verify server is listening on all interfaces (0.0.0.0):**
Your server should bind to `0.0.0.0:8000` not `127.0.0.1:8000`

**3. Test connection from phone:**
```bash
# From phone's terminal or browser
ping 172.20.10.9
curl http://172.20.10.9:8000/health
```

**4. Check both devices are on same WiFi:**
- Phone WiFi SSID = Laptop WiFi SSID
- Both should be on 172.20.10.x subnet

### If IP address changes:

When your laptop gets a different IP address, update:
1. `lib/core/constants.dart` (2 places)
2. `lib/services/remote_ai_service.dart` (1 place)

Or use environment variable:
```bash
flutter run --dart-define=NALAM_API_BASE_URL=http://NEW_IP:8000
```

## Server Requirements:

Your laptop server should:
1. Listen on `0.0.0.0` (all interfaces), not just localhost
2. Have ports 8000 and 8080 accessible on the network
3. Be on the same WiFi as your phone
4. Have firewall rules allowing incoming connections

## Example Server Start Command:

```bash
# Python FastAPI example
uvicorn main:app --host 0.0.0.0 --port 8000

# Node.js Express example
app.listen(8000, '0.0.0.0', () => {
  console.log('Server listening on 0.0.0.0:8000');
});
```

## Need to Switch Back to Localhost?

If you want to test with emulator on localhost again:

**For emulator:** Use `10.0.2.2:8000`  
**For iOS simulator:** Use `127.0.0.1:8000`  
**For physical device:** Use `YOUR_LAPTOP_IP:8000`
