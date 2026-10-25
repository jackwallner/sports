---
paths:
  - "Sideline/Views/TodayBriefingView.swift"
  - "Sideline/Views/Components/PersonaRail.swift"
  - "Sideline/Views/Components/BriefingRundown.swift"
  - "Shared/Utilities/UnfoldedSplit.swift"
  - "Sideline/Debug/EdgeCaseBriefing.swift"
---

# Gist: iPhone Duo (2026-10-22)

- Unfolded (regular width, at least 720 pt), `TodayBriefingView.briefingRoot`
  puts the briefing stack (rooms rail, deck, footer, and Settings when pushed)
  on the leading side of the fold and `BriefingRundown` on the trailing side.
  The rundown lists the same briefing in deck order; the open row is the card
  on top of the deck, with its backstory and source, and tapping a row moves
  the deck. Folded, and on every ordinary iPhone, the rundown is hidden and the
  phone layout is unchanged.
- Fold edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division)`), else an even split; math in
  `Shared/Utilities/UnfoldedSplit.swift`, tested by `UnfoldedSplitTests`.
- One view tree: folding only changes frames, so the deck keeps its card and
  flip. Each pane gets `horizontalSizeClass = .compact`, and the stack gets
  `horizontalToolbarInPane` so iOS 27.1 does not move its toolbar into a
  vertical bar beside the fold.
- `sideline://room/<persona>?card=N` switches room like a rail tap (a locked
  room opens its Pro preview) and opens the deck on card N (0 brief, 1...n
  stories, n+1 question). Do not use it as a gh-sim `--url`: on iOS 27.1
  `simctl openurl` raises an "Open in Gist?" alert that stays over every later
  shot, inner ones included.
- Captures: one `gh-sim all --device 'iPhone Duo'` run with `--args
  "-SidelineSafeScreenshot -SidelineForcePro"` and one `--screen "-DuoScreen
  <surface>"` per surface, never `--url`. `DuoScreen` (DEBUG,
  `Sideline/Debug/EdgeCaseBriefing.swift`) seeds onboarding, the swipe hint and
  the room before any view reads them: `brief`, `story`, `date`, `question`,
  `settings`. Don't also pass `-sideline.lastPersona`: the argument domain
  overrides the seeded room. The safe screenshot briefings stamp card art
  checked by eye and already on Pollinations' CDN (`ScreenshotArt`); the
  derived house-style art drew garbled scoreboard lettering on those stories,
  and uncached art waits on the free tier's one image per 45 s per IP.
- `-SidelineSafeScreenshot` also suppresses the review ask; every `--screen`
  relaunch counts as a launch.
- The rooms rail masks its horizontal scroll view to its frame. Unmasked, it
  drew under the outer display's iOS 27.1 vertical bar, behind the status bar.
  It scrolls the selected room into view, and the rundown reveals its open row
  on appear (a launch that opens on a later card fires no index change) with
  the least movement; centering every row left a faded fragment under the
  header. The
  rundown's header is pinned above its scrolling rows: when it scrolled with
  them, centering a later row hid the pane's title and ran the header under
  the inner display's status bar. Rows fade out under it through a 32 pt
  background overlay; a mask there also clipped the bottom safe area.
- The root `ZStack` fills its proposal before its background; without that
  the unfolded inner display showed white 42 pt side insets.
