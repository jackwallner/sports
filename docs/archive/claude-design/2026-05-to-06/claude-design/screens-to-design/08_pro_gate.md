# 08 — Locked Persona / Pro Gate

**Target:** the interaction triggered from a locked `PersonaChip` (`04`) and the Settings Local-team row (`06`); presents `PaywallView` (`09`).
**Priority:** P0 — this is the conversion moment.
**Status:** Does not exist. Greenfield.

## Job
When a free user taps a Pro persona, don't slam a wall. Show them *what that room sounds like* so the paywall is an obvious yes. The gate is a **preview, not a barrier**.

## The pattern to design
Tapping a locked chip presents a gate that:
- Names the persona and its one-line promise (from `PRODUCT.md`).
- Shows a **blurred / teaser** version of that persona's actual briefing — enough shape and a readable TL;DR-ish line, the rest shimmer/redacted — so they feel the difference vs Cocktail Party.
- One clear primary CTA → paywall (`09`). One quiet dismiss back to their current briefing.
- States the concrete unlock: "all 5 contexts · fresh 3×/day · your local team."

Design two candidate forms and recommend one:
- **A:** a partial-height sheet over the current briefing (context preserved behind it).
- **B:** the chip switches and the briefing area itself renders blurred with an unlock CTA overlaid (feature-preview-in-place).

## What we don't want
- A full-screen takeover that reads "PAY US."
- Fake/lorem teaser content — use realistic teaser copy (a plausible Office Watercooler line, partially obscured).
- A different lock vocabulary than `04`/`06`/onboarding p2.
- Guilt copy or countdate/scarcity.

## Constraints
- iOS 17 SwiftUI (`.sheet` or in-place blur via `.blur` + overlay). Dark mode, AX5.
- Dismiss must return to the user's previous (unlocked) persona with nothing lost.
- VoiceOver: announce it as a preview of a Pro context, not as an error.

## Questions your mockup must answer
1. A vs B — which converts without feeling cheap? Argue it.
2. How much of the teaser is legible? (Too much = no reason to pay; too little = no desire.) Specify exactly what's shown vs obscured.
3. Does the gate name the price, or defer all pricing to the paywall? (We lean: tease value here, price on `09`.)
