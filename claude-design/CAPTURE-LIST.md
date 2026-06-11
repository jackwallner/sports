# Capture list — you take these, Claude Design only frames them

Your raw screenshots ARE the screen content of the final store images.
Claude Design will not redraw anything, so capture with good data: pick a
day/persona where the briefing copy reads well (current, witty, no truncated
lines, no error/empty states).

## Setup (exact 1320×2868 captures, clean status bar)

```sh
# Boot the 6.9" simulator (iPhone 17 Pro Max; 16 Pro Max also works)
xcrun simctl boot "iPhone 17 Pro Max"

# Classic store status bar: 9:41, full bars, full battery
xcrun simctl status_bar "iPhone 17 Pro Max" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3

# Run the app from Xcode on that simulator, then for each screen:
xcrun simctl io "iPhone 17 Pro Max" screenshot claude-design/raw/raw-1-deck-lead.png
```

`simctl io screenshot` on this device produces 1320×2868 px natively, which
is the only iPhone size App Store Connect requires. Verify with
`sips -g pixelWidth -g pixelHeight claude-design/raw/*.png`.

## The 5 captures

| File | Screen / state |
|---|---|
| `raw-1-deck-lead.png` | Today briefing, deck on the lead (TL;DR) card. Free persona selected in the rail. The hero shot. |
| `raw-2-talking-point.png` | Deck swiped to a strong talking-point card: card art visible, a tag pill (nice guy / drama), source line. Pick the wittiest point of the day. |
| `raw-3-card-back.png` | Same (or another) point card flipped to its back, showing the backstory ("in case they ask"). |
| `raw-4-personas.png` | Today screen with the persona rail prominent; ideally mid-scroll so several personas (Cocktail Party, Office Watercooler, Date Night...) are visible. |
| `raw-5-question.png` | Deck on the suggested-question card. |

Light mode for all five. If the daily briefing content is weak today, wait
for tomorrow's generation or switch personas; do not ship a boring line in
the hero frame.

When done, the raws live in `claude-design/raw/` and you paste
`SCREENSHOT-PROMPT.md` into Claude Design (link this repo via "+" → Link
local code).
