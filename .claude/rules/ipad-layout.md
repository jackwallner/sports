---
paths:
  - "Sideline/Views/TodayBriefingView.swift"
  - "Sideline/Views/OnboardingView.swift"
  - "Sideline/Views/Components/BriefingRundown.swift"
  - "Sideline/Info.plist"
  - "SidelineUITests/IPadCaptureUITests.swift"
  - "project.yml"
---

# Gist: iPad layout (2026-11-12)

iPad is free of any gate: `TARGETED_DEVICE_FAMILY "1,2"`, all four orientations
(`UISupportedInterfaceOrientations~ipad`). Once a version ships with iPad it
cannot be removed, so every screen must look designed for it.

- The iPad uses the same two panes as the unfolded Duo: at regular width of at
  least 720 pt the rooms rail and deck sit on the left, `BriefingRundown` on the
  right (`UnfoldedSplit`, even halves, no fold). Split View halves and the
  iPhone are compact and keep one column.
- Content never stretches with the pane. `TodayBriefingView.readableWidth`
  (600) caps the rail, deck and rundown and centres them in their pane;
  `deckMaxHeight` (900) keeps the card phone-shaped on a 13-inch iPad held
  upright. Without it the card was 516 x 1100 pt.
- The deck is top-aligned in its pane. Onboarding is one centred 604 pt
  column (`OnboardingView.pageWidth`); the room-pick page is vertically
  centred. The paywall already caps at 520 and the Pro preview is a form sheet.
- Captures: `SidelineUITests/IPadCaptureUITests` sets
  `XCUIDevice.shared.orientation` and attaches `XCUIScreen.main.screenshot()`
  for the four main screens, both onboarding pages, the Pro preview and the
  paywall. Landscape frames come back as a rotated 2064x2752 portrait buffer:
  rotate 90 degrees in post (`app.screenshot()` clips them). Run
  `gh-sim test --scheme SidelineUITests --only
  SidelineUITests/IPadCaptureUITests --device "iPad Pro 13-inch (M5)"`; frames
  come back as attachments (map names through `attachments/manifest.json`).
  Expect 15 to 60 minutes on a busy queue.
- `testCaptureStore` and `testCaptureStoreBack` produce the raw 2064x2752 frames
  for the App Store iPad set (`-SidelineDeckStart` 0 to 4, plus one flipped card).
