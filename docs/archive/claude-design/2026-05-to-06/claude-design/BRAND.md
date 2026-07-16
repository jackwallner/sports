# The Sideline — Brand & Visual Tokens (proposed)

Greenfield: nothing is set yet, so you have real latitude here — but propose *additions to system*, not a hue zoo, and every token needs a light **and** dark value. The engineer pastes your final `tokens/COLORS.md` into `Shared/Utilities/Theme.swift` verbatim, so write it as real Swift.

## The feeling
"Sports bar at golden hour, but tidy." Warm, grounded, a little vintage-press. Confident type doing most of the work. Not neon, not pastel, not corporate-blue.

## Typography
- System font (SF Pro) only. Hierarchy via SwiftUI text styles: `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.caption`, `.footnote`.
- The **TL;DR** is the hero string on the main screen — propose its style (candidate: `.title3.weight(.semibold)`, generous line spacing). It should out-rank the headline visually because it's what the user actually says out loud.
- Talking points: `.body`. Pop-culture tie-in: `.callout` + `.foregroundStyle(.secondary)` + italic. Source line: `.caption` secondary.
- Bold reserved for headline + the human-interest tag label. Avoid bold sprawl.

## Color (proposed — refine in `tokens/COLORS.md`)
| Token | Light | Dark | Used for |
|---|---|---|---|
| `brandPrimary` | deep field green `#1F5C45` | `#3F8F6E` | Wordmark, primary CTA, selected persona chip |
| `brandAccent` | amber `#E0A21A` | `#F2B945` | Highlights, "Pro" affordance, suggested-question card edge |
| `surface` | `Color(.systemBackground)` | system | App background |
| `card` | `Color(.secondarySystemBackground)` | system | Bullet cards, briefing container |
| `textPrimary` | `Color(.label)` | system | Default text |
| `textSecondary` | `.secondary` | system | Source line, tie-in, captions |
| `tagNiceGuy` | green `#2E7D4F` | `#54B27E` | `nice guy` / `redemption` tag pill |
| `tagJerk` | muted brick `#B4452F` | `#D9694F` | `jerk` / `drama` tag pill |
| `tagNeutral` | slate `Color(.systemGray)` | system | `neutral` tag pill |

Notes you must resolve in your spec:
- `nice guy` and `redemption` share a hue here, `jerk` and `drama` share another. Decide whether they should be distinguishable (different symbol? lighter shade?) — the user scans these fast and the distinction is part of the fun.
- Amber on a light background can fail contrast. Specify the on-amber text color and a darker amber-text variant for inline use.

## Iconography
- SF Symbols only. Deliver **exact symbol names**, not drawings.
- **Persona glyphs** (one per chip) — name a symbol for each: Cocktail Party, Sports Talk for Moms, Office Watercooler, Date Night, Local Team. (Candidates to evaluate, not mandates: `wineglass`, `figure.2.and.child.holdinghands`, `cup.and.saucer`, `heart.text.square`, `mappin.and.ellipse`.)
- **Human-interest tags** — name a symbol per tag: `nice guy`, `jerk`, `redemption`, `drama`, `neutral`. (Candidates: `hand.thumbsup`, `hand.thumbsdown`, `arrow.uturn.up`, `flame`, `circle`.)
- Size mapping: persona chip glyph `.title3`; tag pill glyph `.caption`; onboarding hero `.system(size: 64)`; empty-state symbol `.system(size: 52)`.

## Corner radius & material
- Briefing container & bullet cards: `RoundedRectangle(cornerRadius: 16)`.
- Persona chips: `Capsule()`.
- Suggested-question card: `cornerRadius: 16`, a 1pt `brandAccent` border to set it apart as "the move."
- Materials: `.regularMaterial` for the persona rail background if it floats; `.ultraThinMaterial` for the offline banner.

## Motion
- Persona switch: cross-fade the briefing, `.easeOut(duration: 0.25)`, `.opacity` (optionally `.combined(with: .move(edge: .top))` at small magnitude). No card-by-card stagger that delays reading.
- Pull-to-refresh: standard system refresh; on success, a single subtle `.symbolEffect(.bounce)` on the freshness clock — nothing more.
- Locked-chip tap → paywall: standard `.sheet`.
- Respect Reduce Motion: fall back to `.opacity` only. No persistent loops, no confetti, ever.

## Copy voice — micro-rules
- Sentence case in buttons ("See all contexts", not "SEE ALL CONTEXTS").
- Second person, specific: "you", "the person you're talking to" — never "users."
- Dry wit allowed in product copy (empty states, upsells); never in a way that ages badly or reads mean.
- The human-interest tag label is one word: `Nice guy`, `Jerk`, `Redemption`, `Drama`, `Neutral`. The *why* is one short sentence under it.
- Numbers: numerals for everything sports-adjacent (scores aren't shown, but counts/days are).
- Exclamation points: at most one per screen, only for genuine delight (purchase success).
- No emoji in product UI. (App Store copy is a separate job.)

## Patterns to establish (there are none yet — you're inventing them)
- **Bullet card**: the atomic unit. talking point (primary) → optional tie-in (secondary italic) → optional tag pill → source line (tappable, quiet). Define it once; it's reused everywhere.
- **Locked affordance**: how a Pro-only persona/feature signals "tap to see what this is" without a hostile lock-wall.
- **Freshness/offline footer**: one consistent component for "Updated 2h ago · 4 sources" and its offline variant.
- **Empty/error**: `ContentUnavailableView`-style — symbol + headline + one line + (optional) retry. Used for first-launch-no-network and fetch failure.
