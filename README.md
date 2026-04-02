# Photo Location Sync

Photo Location Sync is a macOS SwiftUI app plus a reusable Swift package for matching Google Maps Timeline export data to Apple Photos assets that are missing location metadata.

## Privacy posture

Photo Location Sync does not send your imported timeline data, coordinates, or match results to external servers. Matching, coordinate labeling, and spatial review run locally on your Mac, and the app avoids online geocoding, remote map tiles, analytics, and crash-reporting services.

Photo previews are allowed to load from iCloud Photos when an asset is not stored locally, so Apple Photos may download image data for display. Separately, when you approve an update, the app writes metadata into Apple Photos locally, and iCloud Photos may sync those approved library changes through Photos after the local write.

## Repository structure

- `Package.swift` — SwiftPM manifest for the reusable modules and the macOS app target
- `App/PhotoLocSyncMac/` — SwiftUI macOS app shell
- `Sources/PhotoLocSyncCore/` — domain models, matching, and workflow orchestration
- `Sources/PhotoLocSyncAdapters/` — Timeline parsing, PhotoKit, local coordinate labeling, and security-scoped file access
- `Tests/` — importer, matcher, pipeline, and manual verification coverage
- `Configuration/` — app bundle metadata used by Xcode and the local bundle-build script
- `Docs/` — migration notes for future iPhone and iPad shells
- `Scripts/anonymize_timeline_fixture.py` — helper used to anonymize a real Timeline export into a safe fixture

## Current v1 workflow

1. Launch the macOS app from Xcode, `swift run PhotoLocSyncMac`, or a generated `.app` bundle.
2. Import a Google Maps `location-history.json` export with the native file picker or drag-and-drop.
3. Grant Photos access.
4. Review proposed location matches in list or map mode.
5. Apply confirmed GPS metadata to Apple Photos.

## Running locally

### Automated verification

```bash
make lint
make test
```

`make lint` builds source and test targets with `-warnings-as-errors`, and `make test` runs the test suite with the same warning-free requirement.

This repository also includes a tracked pre-commit hook at `.githooks/pre-commit`. Enable it in your clone with:

```bash
git config core.hooksPath .githooks
```

### Build a macOS `.app` bundle

Use the packaging script to build the SwiftPM app target and wrap it in a local macOS app bundle:

```bash
python3 Scripts/build_app_bundle.py
```

Notes:

- The default output is `.build/bundle/PhotoLocSyncMac.app`.
- Use `--configuration debug` if you want a debug bundle instead of the default release build.
- Add `--open` to launch the packaged app as soon as the bundle has been written.

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
