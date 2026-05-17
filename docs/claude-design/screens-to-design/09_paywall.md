# 09 — Paywall (RevenueCat remote spec + fallback card)

**Target:** `Sideline/Views/PaywallView.swift`
**Priority:** P0 — revenue surface.
**Status:** Does not exist. Greenfield. (Same RevenueCat pattern as the user's Posture app: `RevenueCatUI.PaywallView` when configured, a hand-built fallback card otherwise.)

## Two deliverables

### A. RevenueCat remote-config input spec (`copy/PAYWALL.md`)
We do **not** hand-code the primary paywall — RevenueCat renders it from a remote config. You design the *inputs*:
- Recommended template family (RevenueCat offers default / minimalist / list / feature-list / image-only — pick one, justify for a witty utility app).
- Hero direction: SF-Symbols composed into one mark, or one simple rendered asset. Minimal. **No real team/league/athlete imagery.**
- Headline (≤6 words). Subhead (≤12 words).
- Up to 4 benefit bullets, each with an SF Symbol: all 5 contexts · fresh 3×/day · local-team personalization · (4th if it earns its place).
- Trial messaging (assume a free trial; do not invent the length — leave a `{trial}` token).
- Pricing display: monthly + annual, annual framed as savings (RevenueCat fills numbers — you spec layout/wording, not the price).
- Restore Purchases placement + T&C / Privacy footer (App Store required).

### B. Fallback card (`mockups/09_paywall_fallback_card.*`)
Shown when RevenueCat isn't configured (debug, offline, misconfig). This **is** hand-built SwiftUI — design it fully: same headline/benefits/CTA, a single "Continue" that triggers purchase, Restore link, dismiss. It must not look broken or placeholder-y; it's a real fallback users can hit.

## Tone
We sell *more conversations*, not "a sports app subscription." Frame: "One room is free. Pro gives you all five — and your team." Confident, dry, no scarcity, no urgency, no "unlock your potential."

## What we don't want
- A pricing table as the hero.
- Urgency/scarcity ("Limited time!") — Apple frowns; we frown harder.
- Localized or seasonal variants (English only, v1).
- A "lifetime" tier — recurring only.
- Any real logos/likenesses in the hero.

## Constraints
- App Store: visible Restore Purchases + reachable T&C/Privacy.
- Fallback card: iOS 17 SwiftUI, dark mode, AX5, dismissible.
- Benefit bullets must match the lock copy used in `04`/`06`/`08` (one consistent value story).

## Questions your mockup must answer
1. Which RevenueCat template, and why it fits a short-witty-utility better than the default.
2. The headline — give 3 candidates in `copy/PAYWALL.md`, recommend one.
3. Fallback card: does it mirror the remote layout closely (consistency) or stay deliberately simple (it's an edge case)? Recommend.
