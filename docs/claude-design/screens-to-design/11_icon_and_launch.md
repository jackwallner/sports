# 11 — App Icon + Launch

**Targets:** App Icon set (`Sideline/Assets.xcassets/AppIcon`), launch mark (launch screen / onboarding p1 hero).
**Priority:** P1 — the icon is the first impression on the home screen and App Store.
**Status:** Does not exist. Greenfield.

## Job
An icon that says "quick, confident, a little witty — sports-adjacent but not a sports app." It should be recognizable at 60pt and not look like ESPN, a sportsbook, or a scoreboard.

## Hard constraints (legal + pipeline)
- **No real team logos, league marks, mascots, or athlete likenesses.** Generic forms only.
- Buildable from simple geometry / a single rendered mark / SF-Symbol-derived shape — no custom illustration pipeline, no mascot.
- 1024×1024 master, no alpha, all required sizes derivable. Light + dark (and tinted, if you opt in) per iOS 17/18 icon variants.

## Direction prompts (give ≥3, recommend 1 in `icon/APP_ICON_BRIEF.md`)
- The "sideline" idea literally: a confident chalk/field-line mark (a stripe, a hash, a boundary) on `brandPrimary`, no ball.
- A speech/quote mark fused with a sideline stripe — "you, in the conversation."
- A single bold glyph in `brandPrimary`/`brandAccent` that reads at 60pt and pairs with the wordmark.
- Explicitly reject: any ball, jersey, whistle-as-cliché, or scoreboard digits.

## Launch
- A calm launch screen: wordmark or the icon mark on `surface`, nothing animated, no spinner (cold start is fast; the briefing fetch handles its own skeleton on `02`).
- The same mark should work as the onboarding page-1 hero (see `01`).

## What we don't want
- Anything that could be mistaken for an existing sports brand.
- Gradient-heavy sportsbook neon.
- An icon that needs the name next to it to make sense (it shouldn't, but it must also *pair* well with "The Sideline").

## Deliverables
- `mockups/11_icon_directions.*` — ≥3 directions at 1024 + a 60pt legibility check for each.
- `icon/APP_ICON_BRIEF.md` — recommended direction, construction notes (geometry/SF-Symbol basis), color tokens used, dark/tinted variants, and the launch-mark spec.

## Questions your mockup must answer
1. Does the icon survive at 60pt and in grayscale? Show the small render.
2. Light/dark/tinted variants — does the chosen mark hold across all three iOS 18 icon modes?
3. Does the mark double as the onboarding hero and launch mark without modification? If not, what's the minimal variant set?
