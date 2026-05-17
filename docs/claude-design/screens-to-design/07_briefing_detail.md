# 07 — Briefing Detail (sheet)

**Target:** `Sideline/Views/BriefingDetailView.swift`
**Priority:** P2 — nice-to-have; may be cut for v1 if the `BulletCard` is self-sufficient.
**Status:** Does not exist. Greenfield.

## Job
When the user wants a little more on one bullet before they bring it up ("wait, why did they bench him?"), give an expanded view of that single bullet with its full context and a clear path to the source — without becoming a news reader.

## Renders
The selected `BulletCard`'s data, expanded: full talking point, full tie-in, the human-interest note in full, and the source as a prominent button (opens `SFSafariViewController`). No article body — we never reproduce reporting; we point to it.

## Presentation
- `.sheet` with detents (`.medium`, `.large`), grabber. Opened by tapping a bullet's body in `02`.
- Same visual language as `BulletCard` — this is a zoom, not a new aesthetic.

## States
- Populated. Dark mode. (No loading — data is already in hand from the briefing.)

## What we don't want
- A scraped/embedded article. Just our framing + a button to the real source.
- A second source experience that contradicts the inline one.
- Scope creep (comments, related, share) — out.

## Constraints
- iOS 17 SwiftUI `.sheet` + `.presentationDetents`. Dark mode, AX5.
- Must be losable cleanly (swipe down / Done) back to the briefing with the scroll position intact.

## The decision this brief exists to force
**Recommend in your mockup whether v1 even needs this.** If the `BulletCard` (`03`) carries enough that tapping in adds nothing but a bigger source button, say "cut for v1, source link on the card is enough" and design only the card. Don't build a sheet just because the slot exists.
