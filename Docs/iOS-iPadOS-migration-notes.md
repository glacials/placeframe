# iOS / iPadOS migration notes

The current package split is intended to make future Apple-platform shells thin:

- Reuse `PhotoLocSyncCore` unchanged for matching, review item generation, and workflow coordination.
- Reuse most of `PhotoLocSyncAdapters` unchanged for Timeline parsing, geocoding, and PhotoKit bridges.
- Replace the macOS import shell with iOS/iPadOS document importer and touch-first review layouts.
- Keep the import contract centered on `Data` rather than long-lived file URLs.
- Preserve explicit review-before-write behavior across all platforms.
