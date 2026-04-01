# Manual Verification Guide

1. Open `PhotoLocSyncMac.xcodeproj` in Xcode.
2. Confirm the app launches to the import instructions screen.
3. Use **Import Timeline Export** to select `location-history.json` or the anonymized fixture.
4. Drag the same file onto the window and confirm drag-and-drop import works.
5. Approve the Photos access prompt.
6. Confirm the processing screen advances through each stage.
7. Review the generated matches in Grid, List, and Map modes.
8. Click **Cancel** and verify no Photos metadata changes were applied.
9. Re-run the flow, click **Apply to Photos**, and confirm expected assets receive locations.
10. Inspect the Apply Result screen for updated, skipped, and failed counts.
