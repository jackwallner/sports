# App Store screenshot package

Flow:

1. **Capture** — follow `CAPTURE-LIST.md` (5 raws into `raw/`, exact
   1320×2868 from the iPhone 17 Pro Max simulator).
2. **Claude Design** — link this repo ("+" → Link local code), paste
   `SCREENSHOT-PROMPT.md`, download results to `output/store/`.
3. **Verify + ship**:
   ```sh
   sips -g pixelWidth -g pixelHeight claude-design/output/store/*.png
   # fix any size drift (height first):
   sips -z 2868 1320 claude-design/output/store/<file>.png
   cp claude-design/output/store/*.png fastlane/screenshots/en-US/
   ```

Key constraint baked into the prompt: Claude Design composites the real
raw screenshots into device frames with marketing copy around them. It must
never recreate or redraw the app UI. ASC accepts only 1320×2868 px portrait
for the required 6.9" iPhone slot (app is iPhone-only, so no iPad set).
