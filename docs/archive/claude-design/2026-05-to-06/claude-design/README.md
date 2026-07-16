# The Sideline — Design Handoff for Claude Design

**Paste this whole folder's context into a fresh Claude Design session.** Start by reading this file top to bottom, then the files in the order below. This folder is self-contained — everything needed to produce designs lives here. There is **no existing code to mirror**: The Sideline is greenfield. The screen briefs in `screens-to-design/` are the source of truth, not screenshots.

## You are designing

**The Sideline** — a SwiftUI iOS app that helps people who *don't* follow sports hold their own in conversations with people who do. The user picks a context ("Cocktail Party", "Sports Talk for Moms", "Office Watercooler", "Date Night", "Local Team") and gets a short, scannable briefing of what's happening in the sports world — framed as conversation fuel (storylines, pop-culture tie-ins, who's the nice guy / who's the jerk), never box scores or stats.

## How to use this folder

1. Read `BRIEF.md` — what we're trying to accomplish and the jobs to be done.
2. Read `PRODUCT.md` — what the app does, who it's for, free vs Pro.
3. Read `CONTEXT.md` — team, constraints, aesthetic taste, what the engineer won't build.
4. Read `BRAND.md` — visual tokens (color, type, motion, copy voice). These are *proposed* since the app doesn't exist yet — you have more latitude here than in a rebrand, but stay inside the hard constraints.
5. Read `INVENTORY.md` — every screen that will exist, in encounter order.
6. Work through `screens-to-design/` — each file is one screen brief with goals, states, constraints, and the questions your mockup must answer.
7. Produce deliverables exactly per `DELIVERABLES.md` — concrete artifacts tied to specific screens/components this app actually renders, with stable filenames so they wire into code without renaming.

## Constraints (non-negotiable — same engineering bar as the user's other apps)

- **SwiftUI on iOS 17+, no UIKit.** Everything must be expressible as native components or SF-Symbol compositions. `UIViewRepresentable` only for `SFSafariViewController` (already planned for source links).
- **No custom font files.** SF Pro only, via system text styles (`.largeTitle`, `.title2`, `.headline`, …).
- **SF Symbols only for iconography.** The only raster/vector imports allowed are the App Icon set and one launch mark. Persona glyphs and human-interest tags must be nameable SF Symbols.
- **Color = system + a small brand token set.** Propose the palette in `BRAND.md`; do not sprawl hues. Dark mode mandatory on every screen.
- **Accessibility mandatory.** VoiceOver order + labels, Dynamic Type to AX5, Reduce Motion fallbacks.
- **Accountless app.** No sign-in, no profile, no "your data" — never design an auth or account screen.
- **Content is AI-generated and source-cited.** Every briefing bullet carries a real source headline + link. Designs must always give the citation a visible, tappable home — this is a trust feature, not a footnote to hide.

## Open questions to ask the user (Jack) if they block you

- Is the launch audience TestFlight friends/family or App Store day-one? Changes polish bar.
- Is "The Sideline" the final name, or a working title? (Affects wordmark + icon.)
- For the free tier's single persona (Cocktail Party), should the once-per-day refresh limit be framed as scarcity ("come back tomorrow") or as an upsell ("Pro refreshes 3×/day")? We lean upsell — confirm.
