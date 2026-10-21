# Google Play store assets

| File | What it is |
|---|---|
| `icon-512.png` | 512 x 512 app icon, no alpha |
| `feature-graphic.svg` | Editable source of the feature graphic (palette from `ui/theme/Theme.kt`, Georgia type) |
| `feature-graphic.png` | 1024 x 500 RGB feature graphic, rendered from the SVG |
| `screenshots/01-todays-stories.png` | Story card front, Cocktail Party room |
| `screenshots/02-backstory.png` | The same card flipped to its backstory and source |
| `screenshots/03-ask-this.png` | The closing "Ask this" question card |
| `screenshots/04-rooms.png` | Free tier "That was one room" card listing the three Pro rooms (no prices) |
| `metadata/android/en-US/` | `title.txt`, `short_description.txt`, `full_description.txt` (fastlane supply layout), copied from `listing/` |
| `listing/` | Listing copy source, plus `release-notes.txt` |

All screenshots are 1080 x 1920 RGB PNGs (Play's 2:1 limit rejects raw 1080 x 2400 captures).

## How they were made (2026-10-21)

- **Feature graphic:** edit `feature-graphic.svg`, then run
  `PYTHON=<python with Pillow> ./render-feature-graphic.sh` (headless Chrome renders it, Pillow flattens it to RGB).
  No league, team or athlete marks; the card shows the app's own screenshot-fixture copy.
- **Screenshots:** debug build on the `agent-emu-2` AVD (API 36, 1080 x 2400), status bar demo mode at 9:41, launched with
  `--ez onboarded true --ez safeScreenshot true --es appearance light` plus:
  01 `--ez forcePro true --ei deckStart 1`; 02 the same, then tap the card; 03 `--ez forcePro true --ei deckStart 4`;
  04 `--ei deckStart 4` (free tier), then one swipe left.
  `safeScreenshot` swaps the live feed for `SafeScreenshotBriefingService` (no real people). Each capture is composited with
  `python compose-screenshot.py <capture.png> <out.png> "<caption>"` ("|" breaks the caption line).
- **Card art check:** the fixture's lead card and its second story card get Pollinations art with garbled lettering
  (a jumbotron and a logo-like sign), so the set avoids them; the first story card's crowd art is clean. Inspect every
  card's art again before recapturing, since Pollinations can change what it serves.
