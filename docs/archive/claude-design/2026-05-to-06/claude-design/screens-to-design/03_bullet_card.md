# 03 — Bullet Card (component)

**Target:** `Sideline/Views/Components/BulletCard.swift`
**Priority:** P0 — the atomic unit. Every briefing is a stack of these. Get it right once.
**Status:** Does not exist. Greenfield.

## Job
Carry one talking point so a non-fan can read it in ~3 seconds, optionally see the pop-culture angle, see at a glance whether this person is the nice guy or the jerk, and reach the source in one tap.

## Data the card renders (from `BriefingDTO.bullets[]`)
- `talking_point` — required, plain language, the primary text.
- `pop_culture_tie_in` — optional, the celebrity/feud/movie angle.
- `human_interest` — optional: `tag` ∈ {`nice_guy`, `jerk`, `redemption`, `drama`, `neutral`} + one-line `note`.
- `source_headline` + `source_url` — required, the citation.

## Required state matrix (deliver all)
1. Full: talking point + tie-in + tag(`nice_guy`) + source.
2. Tag = `jerk`.
3. Tag = `redemption`.
4. Tag = `drama`.
5. Tag = `neutral`.
6. No tag (human_interest absent) — card must not look broken.
7. No tie-in (tie-in absent).
8. Minimal: talking point + source only.
9. Dark mode for the full + jerk states.
10. Long talking point (3+ lines) — confirm layout holds, source line doesn't get orphaned.

## Tag pill spec to resolve
- `nice_guy` / `redemption` use `tagNiceGuy`; `jerk` / `drama` use `tagJerk`; `neutral` uses `tagNeutral` (see `BRAND.md`).
- **You must decide** how `nice_guy` vs `redemption` (same color) and `jerk` vs `drama` (same color) stay distinguishable at a glance — different SF Symbol per tag is the likely answer; specify each in `symbols/SF_SYMBOLS.md`.
- Pill = symbol + one-word label (`Nice guy`, `Jerk`, `Redemption`, `Drama`, `Neutral`) + the one-line note. Decide: note inside the pill, or beside/under it.

## Source line spec
- Quiet by default (`.caption`, secondary), but obviously tappable. Format: source headline, possibly truncated, + a small link symbol. Tap → `SFSafariViewController` with `source_url`.
- It must never be hidden behind a tap-to-reveal — it's a standing trust signal.

## What we don't want
- A card that screams. The tag is the only color moment; everything else is calm type.
- Logos, avatars, thumbnails.
- The tag reading as cruel — it's playful "tea," and copy carries that; visually keep the jerk/drama color muted, not alarm-red.

## Constraints
- Pure SwiftUI, composes inside a `ScrollView`/`LazyVStack` of unknown count. No fixed height.
- VoiceOver: read order = talking point → tie-in → "tagged: jerk, <note>" → "source: <headline>, link". The tag's spoken form must include the word.
- Dynamic Type AX5 must not clip the pill or orphan the source line.

## Questions your mockup must answer
1. Tag placement: inline after the talking point, or a distinct row above the source? Show the most scannable option.
2. Is the tie-in visually subordinate enough to skip on a fast read but present for a slow one?
3. Does the card need a leading accent (e.g. a thin colored edge by tag) or is the pill enough? Argue one.
