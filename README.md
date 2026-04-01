# Photo Location Sync

Photo Location Sync is a macOS SwiftUI app plus a reusable Swift package for matching Google Maps Timeline export data to Apple Photos assets that are missing location metadata.

## Repository structure

- `Package.swift` — SwiftPM manifest for the reusable modules and the macOS app target
- `App/PhotoLocSyncMac/` — SwiftUI macOS app shell
- `Sources/PhotoLocSyncCore/` — domain models, matching, and workflow orchestration
- `Sources/PhotoLocSyncAdapters/` — Timeline parsing, PhotoKit, geocoding, and security-scoped file access
- `Tests/` — importer, matcher, pipeline, and manual verification coverage
- `Configuration/` — reference `Info.plist` and entitlements for a future packaged app bundle
- `Docs/` — migration notes for future iPhone and iPad shells
- `Scripts/anonymize_timeline_fixture.py` — helper used to anonymize a real Timeline export into a safe fixture

## Current v1 workflow

1. Launch the macOS app from Xcode or `swift run PhotoLocSyncMac`.
2. Import a Google Maps `location-history.json` export with the native file picker or drag-and-drop.
3. Grant Photos access.
4. Review proposed location matches in grid, list, or map mode.
5. Apply confirmed GPS metadata to Apple Photos.

## Running locally

### Automated verification

```bash
swift build
swift test
```

### Hot reload during development

Use the watcher script to rebuild and relaunch the app whenever Swift or configuration files change:

```bash
python3 Scripts/hot_reload.py
```

Notes:

- The script watches `App/`, `Sources/`, `Configuration/`, and `Package.swift`.
- On each successful rebuild it terminates the old app process and launches the new binary immediately.
- If a rebuild fails, the current app instance keeps running so you can fix the error and save again.
- To skip the initial test run:

```bash
python3 Scripts/hot_reload.py --no-tests
```

### Open the app in Xcode

Open `Package.swift` in Xcode 26+ and run the `PhotoLocSyncMac` executable target.

## Fixture provenance

`Tests/PhotoLocSyncAdapterTests/Fixtures/location-history-anonymized.json` was anonymized from a real Timeline export while preserving structure and ordering. Do not commit raw exports.

## Manual verification

Follow `Tests/PhotoLocSyncManualTests/MANUAL_TEST_GUIDE.md` for end-to-end checks against a real Photos library.
