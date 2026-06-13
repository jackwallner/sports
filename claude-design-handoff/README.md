# The Sideline — Claude Design handoff

## What the app is

**The Sideline** is a native iOS (SwiftUI, iOS 17+) app that gives daily, source-cited
sports talking points to people who **don't follow sports but have to talk to people who do**.
The user isn't a fan — they're a parent of a sports-obsessed kid, a coworker surviving Monday
watercooler chat, someone on a date, a person at a cocktail party. They open the app once, grab
a few witty, current, defensible lines, and put their phone away.

The tone is **warm, a little witty, confident but never bro-y or jargon-heavy**. It's the
opposite of ESPN: no stats walls, no hot takes, no insider voice. Content is organized by
**persona** — the app calls them "rooms" (Cocktail Party, Sports Talk for Moms, Office
Watercooler, Date Night), and each daily briefing is a swipeable card deck: a lead "gist" card,
a few full-bleed talking-point cards (generated art, an optional "nice guy / drama" character
tag pill, tap-to-flip backstory with a source link), and one suggested-question card. One free
persona; the rest are Pro.

It is a calm, glanceable, text-first reading app — closer to a well-designed newsletter or a
Things/Reader-style utility than a sports scoreboard app. Trust and freshness matter (every
point is sourced); clutter and hype are the enemy.

## What's in this folder

- `current/` — the project's **real** design primitives, to replace in place:
  - `Theme.swift` — the single source of truth for color and the card corner radius
    (`SidelineTheme`). This is the file your token output should drop into.
  - `LaunchBackground.colorset.json` — the launch-screen brand color (same green as `brandPrimary`).
  - `current-app-icon.png` — the current 1024×1024 app icon (green field, white quotation
    mark, gold underline = "the line" / sideline). Treat as the thing we're trying to beat.
- `source/` — **copies** of the real UI so you can see how tokens are used in practice:
  - `TodayBriefingView.swift` — the main screen (rooms rail, swipeable card deck, freshness
    footer).
  - `Components/` — the reusable pieces: `PersonaRail`, `BriefingDeck` (the card deck: lead
    gist card, talking-point card front/back, suggested-question card), `FreshnessFooter`.
  - `OnboardingView.swift`, `PaywallView.swift`, `SettingsView.swift` — supporting screens.
  - `Persona.swift`, `Briefing.swift`, `BriefingTag.swift` — the data model, so you understand
    what content the components render (personas, tags, sources).

## What we want back

1. **App icon** — 3–5 concepts at 1024×1024 PNG.
2. **Visual system** — colors, type scale, spacing, and the core components — delivered in
   **two stages** (see `PROMPT.md`). Final tokens must be **drop-in Swift** that replaces
   `current/Theme.swift`, plus 4–6 component PNGs and a short rationale.

## What we do NOT want

- **No full screen redesigns.** Don't re-lay-out `TodayBriefingView` or invent new screens.
  We want a visual system and an icon, not a product redesign.
- **No mood boards, no brand-strategy decks, no naming/positioning exercises.** The product,
  name, and tone are settled.
- **No new dependencies or asset pipelines.** Tokens go in `Theme.swift`; that's the integration
  surface.
- **No screenshots needed from us** — work from the source files in this folder.
