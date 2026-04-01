# Manual Verification Guide

1. Open `PhotoLocSyncMac.xcodeproj` in Xcode.
2. Confirm the app launches to the import instructions screen.
3. Use **Import Timeline Export** to select `location-history.json` or the anonymized fixture.
4. Drag the same file onto the window and confirm drag-and-drop import works.
5. Approve the Photos access prompt.
6. Confirm the processing screen advances through each stage.
7. Review the generated matches in Grid and Map modes.
8. Click **Cancel** and verify no Photos metadata changes were applied.
9. Re-run the flow, click **Apply** on one photo card, and confirm the location is written in Apple Photos without leaving the review screen.
10. Verify the next photo becomes selected and scrolls into view; if the last photo of a day is actioned, confirm the first photo of the next day is selected.
11. Click **Skip for Now** on a photo, confirm it disappears for the current session, then re-import the same timeline and confirm it can appear again.
12. Click **Never Show Again** on a photo, re-import the same timeline, and confirm that photo is not surfaced again.
