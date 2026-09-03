# Offline maps and routing

The route screen uses Magic Lane road-map packages. These packages include the
rendering data and the road graph needed for on-device route calculation.

## First use

1. Build with the local dart-define file:

   ```sh
   flutter run --dart-define-from-file=config.json
   ```

2. Open a recommended facility and select **View on Map**.
3. Select **Download Kerala Map**. If more than one Indian package intersects
   Kerala, choose the Kerala-only package when it is available.
4. Keep the app open and connected until the progress reaches 100%.
5. Select **Calculate Offline Route** and grant foreground location access.
6. Select **Start Navigation** for live GPS guidance.

After step 4, map rendering, route calculation, and navigation work locally.
Route calculation is configured with `allowOnlineCalculation: false`, so it
will fail instead of silently using an online routing service when downloaded
road data does not cover the start or destination.

## Configuration

Copy `config.example.json` to `config.json` and set:

```json
{
  "NALAM_API_BASE_URL": "http://YOUR_SERVER_IP:8000",
  "MAGICLANE_API_TOKEN": "YOUR_MAGIC_LANE_PROJECT_API_KEY"
}
```

Use the **Project API Key** created for the Flutter project in the Magic Lane
developer portal. The phone needs internet access for the first authorization
check and while listing/downloading the map package. It does not need internet
for route calculation after the road map is installed.

`config.json` contains credentials and is ignored by Git for new clones. If it
was already tracked in an existing clone, remove it from the Git index before
committing:

```sh
git rm --cached config.json
```

Do not delete the local file after removing it from the index.

## Offline test

Once the package is downloaded:

1. Enable airplane mode, then turn GPS back on.
2. Reopen the route screen.
3. Confirm the badge reports that the road map is ready offline.
4. Calculate a new route. A road-following result confirms local pathfinding.

The bundled facilities currently use demo coordinates around Ernakulam. Replace
their `latitude` and `longitude` values with coordinates from the production
facility database before release.

## Android development target

The app currently packages `arm64-v8a` native libraries only. This matches the
physical Android phones used for development and keeps the APK manageable when
bundling both local AI and map engines. Add other ABIs back before targeting
32-bit ARM hardware or an x86 Android emulator.
