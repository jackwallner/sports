# 04 — Persona Rail (component)

**Target:** `Sideline/Views/Components/PersonaChip.swift` (+ the rail container in `TodayBriefingView`)
**Priority:** P0 — it's both the navigation and the primary Pro upsell surface.
**Status:** Does not exist. Greenfield.

## Job
Let the user switch the *room* they're prepping for, and make the four Pro rooms visibly desirable to a free user without nagging.

## The five chips (order = product priority)
`Cocktail Party` (free) · `Sports Talk for Moms` (Pro) · `Office Watercooler` (Pro) · `Date Night` (Pro) · `Local Team` (Pro). Each chip = persona glyph (SF Symbol, see `BRAND.md`/`SF_SYMBOLS.md`) + short label.

## Chip states (deliver all)
- **Selected** (free user, Cocktail Party): `brandPrimary` fill, clearly active.
- **Unselected + unlocked**: only Cocktail Party for free users.
- **Locked (Pro)**: visible, legible, with a consistent lock affordance — a small `lock`/sparkle, dimmed, or a "Pro" micro-tag. Tap → does NOT switch; routes to the gate (`08`) / paywall.
- **Selected (Pro user, any chip)**: same as free-selected; no lock anywhere once subscribed.
- Dark mode.

## Interaction
- Tap unlocked chip → cross-fade briefing (see `motion/PERSONA_SWITCH.md`).
- Tap locked chip → present gate/paywall (`08`/`09`). Selected chip does not change.
- Rail scrolls horizontally; selected chip should auto-scroll into view on appear.

## What we don't want
- Hiding the Pro personas from free users — they must be *visible and tempting*, that's the conversion lever.
- A hostile lock (no big padlock-over-everything). Tasteful, inviting.
- More than one lock vocabulary across the app — this, onboarding p2, and the gate must match.

## Constraints
- iOS 17 SwiftUI, dark mode, AX5. Lock state must be conveyed to VoiceOver ("Office Watercooler, Pro, locked — double-tap to learn more").
- Glyphs are SF Symbols only; if a persona has no good symbol, pick the least-bad and note it.
- Free user always has exactly one selectable chip — design so that doesn't feel broken or empty.

## Questions your mockup must answer
1. Lock affordance: dim + `lock` glyph, a "Pro" capsule tag, or a sparkle accent? Pick one and apply it identically in onboarding p2 and the gate.
2. Does the rail show all 5 always, or free users see Cocktail Party + a single "Unlock 4 more contexts" chip? Argue the higher-converting one.
3. Selected-chip emphasis: fill, underline, scale, or glyph weight change? Must survive dark mode + Dynamic Type.
