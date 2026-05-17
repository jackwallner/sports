# 10 — Refresh-Limit Upsell State

**Target:** inline state in `Sideline/Views/TodayBriefingView.swift` (triggered on pull-to-refresh)
**Priority:** P1 — a recurring, low-pressure conversion touch.
**Status:** Does not exist. Greenfield.

## Job
A free user already got today's fresh Cocktail Party briefing and pulls to refresh again. There's nothing new for them until tomorrow (free = 1×/day; Pro = 3×/day). Turn this dead-end into a calm upsell, not an error.

## The moment
- User pulls to refresh → gating says `canRefresh == false` for free tier today.
- Don't show a spinner-then-nothing, and don't show an error.
- Show a brief, friendly inline message + a soft Pro nudge, then settle back to the existing (still-valid) briefing.

## Spec direction
- An inline banner or a transient card near the top, e.g.: eyebrow "You're caught up", line "Today's briefing is already the latest. Pro refreshes 3× a day — morning, midday, and evening." + a quiet "See Pro" affordance → paywall (`09`).
- The existing briefing stays visible and usable underneath. This is additive, dismissible, never blocking.
- Frame as upsell, not scarcity (per README open question — confirmed lean: upsell). Avoid "come back tomorrow" guilt; lead with what Pro gets.

## States
- Free, limit hit (the case). Dark mode.
- (Pro users never see this — refresh always proceeds. Note that, no design needed.)

## What we don't want
- A modal or full takeover for a refresh tap.
- An error icon / red anything — nothing failed.
- Repeated nagging if they pull again — show it, then be quiet (don't re-animate aggressively on every subsequent pull in the same session).

## Constraints
- iOS 17 SwiftUI; integrates with the standard `.refreshable` pull gesture. Dark mode, AX5.
- Copy must match the Pro value story in `04`/`06`/`08`/`09`.
- Reduce Motion: no bounce; fade only.

## Questions your mockup must answer
1. Banner vs transient card vs a subtle change to the freshness footer ("Next free update tomorrow · Pro: 3×/day")? Recommend the least annoying that still converts.
2. How does it dismiss/decay — auto after N seconds, on scroll, or persist quietly until tomorrow?
3. One exposure per day or every pull? Argue the non-annoying choice.
