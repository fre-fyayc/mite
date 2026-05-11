# MiteTool (macOS MVP)

Native SwiftUI macOS app to create MITE time entries with:
- recurring presets (`project + service + default note/minutes`)
- manual entries for one-off work
- API key storage in macOS Keychain

## Run Locally

From this folder:

```bash
swift build -c debug
swift run MiteTool
```

The app opens a window with `Quick Add`, `Manual`, and `Settings`.

## Build .app Bundle

To create a Finder-launchable app bundle:

```bash
./scripts/make_app_bundle.sh
open "dist/MiteTool.app"
```

This also generates and embeds a Finder icon (`AppIcon.icns`) from `GlassTimeTrackerIcon`.

## First-Time Setup

1. Open `Settings`.
2. Enter your MITE account subdomain (for `https://<subdomain>.mite.de`).
3. Enter your API key.
4. Click `Save Credentials`.
5. Click `Test Connection`.
6. Click `Refresh Projects + Services`.

After refresh, go to `Quick Add` and create your first preset.

## Testing Manually

- **Quick Add:** create/edit/delete/reorder presets, then click `Log Selected Preset`.
- **Manual:** choose project/service/date/minutes/note and click `Save Entry`.
- **Validation:** try missing fields to see inline error messaging.

## Notes

- API behavior follows MITE JSON endpoints and `X-MiteApiKey` authentication:
  [MITE API docs](https://mite.de/en/api/)
- In this environment, `swift test` is toolchain-limited for test frameworks.
  The app itself builds and runs successfully.
