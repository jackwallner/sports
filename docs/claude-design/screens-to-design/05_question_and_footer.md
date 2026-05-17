# 05 — Suggested Question + Freshness Footer

**Targets:** `Sideline/Views/Components/SuggestedQuestionCard.swift`, `Sideline/Views/Components/SourceFootnote.swift`
**Priority:** P1 — the question is the conversational payoff; the footer is the trust signal.
**Status:** Do not exist. Greenfield.

## Part A — Suggested Question card

### Job
After the talking points, hand the user one open question they can ask a fan to keep the conversation going (and shift the work onto the fan). It's the satisfying full-stop of the briefing — "you're ready."

### Renders
`BriefingDTO.suggested_question` — one string. Sample: *"Do you think they made the right call, or did they just blow up their season?"*

### Spec direction
- Visually distinct from `BulletCard` — it's an action, not info. Candidate: a card with a 1pt `brandAccent` border + a small "Ask them this" eyebrow label + the question in a slightly larger, confident type.
- It is the last thing on the screen. It should feel like a destination, not another bullet.
- Not interactive in v1 (no copy button, no share) unless you make a strong case — keep scope tight.

## Part B — Freshness / source footer

### Job
Tell the user how current the briefing is and that it's grounded in real reporting — without turning into clutter. Freshness is a trust feature.

### Renders
- Online: relative time from `generated_at` + source count, e.g. *"Updated 2h ago · 3 sources"* (a small clock SF Symbol).
- Offline: e.g. *"Offline — last updated yesterday"* with an offline SF Symbol; `.ultraThinMaterial`.
- (Per-bullet source links live on the `BulletCard` itself — this footer is the aggregate signal, not a link list.)

### States (deliver)
- Fresh (<1h), normal (hours ago), stale (yesterday/days), offline. Dark mode.

## What we don't want
- The question card looking like a 7th bullet.
- A footer that competes with the question for attention — it's quiet, persistent, trusted.
- A list of every source URL in the footer (sources belong on their bullets).

## Constraints
- iOS 17 SwiftUI, dark mode, AX5. Relative time via the planned `DateHelpers` formatter.
- VoiceOver: question read as "Suggested question: …"; footer as "Updated 2 hours ago, 3 sources" / "Offline, last updated yesterday."

## Questions your mockup must answer
1. Footer placement: pinned to the bottom of the scroll, or flowing right after the question card? Recommend.
2. Does the question card get one accent treatment that nothing else in the app uses, so it always reads as "the move"?
3. Stale/offline: how loud is the warning before it becomes anxiety rather than information?
