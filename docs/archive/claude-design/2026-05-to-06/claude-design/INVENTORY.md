# Screen Inventory

Every user-facing surface The Sideline will have, in the order a new user meets it. No `code-references/` — nothing is built yet; the linked `screens-to-design/` brief is authoritative for each.

| # | Screen / surface | Brief | One-line |
|---|---|---|---|
| 1 | Onboarding (3 pages) | `screens-to-design/01_onboarding.md` | Value prop → pick starting context → optional city/team (Pro taste). |
| 2 | Today Briefing | `screens-to-design/02_today_briefing.md` | The core screen: persona rail + headline + TL;DR + bullet cards + question + freshness. |
| 3 | Bullet Card (component) | `screens-to-design/03_bullet_card.md` | The atomic unit, in every tag state. Reused everywhere. |
| 4 | Persona Rail (component) | `screens-to-design/04_persona_rail.md` | Horizontal chip switcher incl. locked/Pro chips. |
| 5 | Suggested Question + Freshness footer | `screens-to-design/05_question_and_footer.md` | "Ask them this" card + "Updated 2h ago · sources" / offline variant. |
| 6 | Settings | `screens-to-design/06_settings.md` | Local-team picker (Pro-gated), restore, manual refresh, about/privacy. |
| 7 | Briefing Detail (sheet) | `screens-to-design/07_briefing_detail.md` | Expanded bullet + source context, opened from a card. |
| 8 | Locked Persona / Pro gate | `screens-to-design/08_pro_gate.md` | Tapping a locked chip — preview, not wall. |
| 9 | Paywall | `screens-to-design/09_paywall.md` | RevenueCat remote-config input spec + hand-built fallback card. |
| 10 | Refresh-limit upsell state | `screens-to-design/10_refresh_limit.md` | Free user pulls to refresh a 2nd time same day. |
| 11 | App Icon + Launch | `screens-to-design/11_icon_and_launch.md` | Icon directions (no real logos) + launch mark. |

## States every data screen must specify
- **Skeleton** (fast network read in progress — *not* an AI think-time spinner; see CONTEXT).
- **Populated** (the normal case — design this first and best).
- **Offline / cached** (show last briefing + quiet "offline" affordance, never a blocking error).
- **Fetch error with no cache** (first launch, no network — `ContentUnavailableView` style + retry).
- **Free-tier limited** (refresh already used today; locked persona tapped).
- **Dark mode** (note any token that needs special handling).

## Things the product allows but the UI must surface well
- Switching personas (free user: only Cocktail Party is unlocked — the rest are visible-but-locked, not hidden).
- Verifying a claim (every bullet's source must be reachable in one tap).
- Knowing how fresh the briefing is (freshness is a trust signal — never bury it).
- Setting a local team (Pro) — discoverable from Settings *and* previewed in onboarding page 3.

## Explicitly NOT in the inventory (do not design)
- Sign-in / account / profile (accountless app).
- Scores / standings / box score / stats / charts.
- News article reader.
- Watch app, widgets.
- Any social / sharing-back / comment surface.
