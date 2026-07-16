# Background context for Claude Design

Everything the implementing engineer knows about The Sideline that doesn't fit BRIEF or PRODUCT. Skim before starting.

## The team
- Jack Wallner — solo developer + designer. iOS engineer; ships native Swift apps (Posture, Bond) solo.
- No design team. You are the design team.
- Implementation is done by another Claude instance treating your output as the source of truth.

## Where the code will be
Project root: `/Users/jackwallner/glptracker` (currently empty — scaffolding in progress).
- `Sideline/` — iOS app (Views, Components)
- `Shared/` — Services, Models, DTOs compiled into the app + tests
- `supabase/migrations/` — Postgres schema for cached briefings
- `SupabaseFunctions/generate-briefings/` — the Claude-backed generator (edge function)
- `claude-design/` — this folder

There is **no `code-references/` folder** in this handoff because no code exists yet. Other apps' handoffs mirror real Swift files; here the `screens-to-design/` briefs are authoritative. When the engineer scaffolds the views, they will conform to your specs, not the reverse.

## The architecture you should design around
- Briefings are **pre-generated server-side** and cached, shared across all users, refreshed 3×/day. The app just *fetches the latest cached briefing* for the selected persona — it never calls an AI live. So: no "generating…" spinner that lasts 10s; fetches are a normal fast network read with an offline cache fallback. Design loading as a quick skeleton, not an AI think-time experience.
- **Offline works.** Last fetched briefing is cached locally (SwiftData). Design an offline state that shows the cached briefing with a quiet "showing yesterday's — offline" affordance, not a blocking error.
- **Pro entitlement is local** (RevenueCat). No server knows who's Pro. Gating is purely client-side UI + the RevenueCat paywall.

## Constraints worth re-stating
- SwiftUI primitives only. iOS 17 minimum (`@Observable`, `.symbolEffect`, `Charts` available — but we have nothing to chart). No UIKit except `SFSafariViewController` for opening a source link.
- SF Symbols only. If a persona or tag needs an icon not in the SF Symbols library, it doesn't get a custom icon — pick the closest symbol and name it.
- System fonts only. SF Pro.
- No third-party UI libs. No Lottie, no Pow, no SwiftUIX.
- Dark mode mandatory, every screen.
- Accessibility mandatory: VoiceOver labels (especially the human-interest tag — "tagged: jerk" must be spoken), Dynamic Type to AX5, Reduce Motion fallbacks.

## What the engineer will NOT do based on your designs
- Add custom fonts.
- Add raster assets beyond the App Icon set + one launch mark.
- Use any real team/league/athlete imagery or names-as-logos.
- Build a scores/standings/stats screen even if it would "help" — it's off-product.
- Hand-code the RevenueCat paywall (it's remote-configured) — but will build the fallback card you spec.
- Implement screens not in `INVENTORY.md` / `screens-to-design/` without asking.

## A note on aesthetic taste
The Sideline should feel like **a sharp friend texting you the tea on your way to the party** — quick, confident, a little funny, never trying too hard. Reference points:
- **NYT Cooking / Letterboxd mobile** — opinionated typography in a calm shell.
- **Things 3** — restraint; nothing on screen that isn't earning its place.
- **Apple News+ digest cards** — scannable card stacks (but warmer, wittier, no publisher chrome).
- **A good morning-briefing email** — TL;DR first, links optional, gone in 30 seconds.

Avoid:
- ESPN / The Athletic / any scoreboard chrome, ticker, or stat table.
- Sportsbook neon, "lock of the day" energy, gradients that yell.
- Wellness-app pastels and watercolor blobs.
- Cutesy mascot. There is no mascot.

When in doubt: calmer, faster to read, drier wit. Warmth comes from the copy, not from decoration.

## How revisions work
If the engineer implements a screen and Jack says "no, like this," you'll get a revised brief with the same filename. Keep your output filenames stable (see `DELIVERABLES.md`) so git diffs stay clean.
