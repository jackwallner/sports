# Gist (The Sideline) — Project Guide

Conversation fuel for people who do not follow sports but have to talk to people
who do: cached, source-cited daily briefings written for a social context rather
than for a fan. XcodeGen project/scheme: `Sideline`, sim lease owner `sports`.
App Store name **Gist**, App Store ID `6770138156`, repo `~/sports`.

## Tech Stack
- Swift 6 / SwiftUI (strict concurrency), SwiftData for the offline cache
- Supabase (Postgres + Edge Functions, Deno/TypeScript) with Gemini generation
- XcodeGen (`project.yml`). Targets: iOS 17+, plus a `Shared` framework
- RevenueCat, gate is `isPro` on `EntitlementProviding` (`RevenueCatEntitlementStore`, or `LocalEntitlementStore` in tests)

## Targets / bundle IDs
- `Sideline` — `com.jackwallner.sports`
- `Shared` — `.shared` (DTOs, services, caching, entitlements; the tests import it)
- `SidelineTests` — `.tests`, `SidelineUITests` — `.uitests`
- No App Group, no widget or watch target

## Architecture
**The app never calls Gemini.** Scheduled backend jobs pull curated RSS feeds,
generate strict JSON briefings, validate them, and store them in Supabase; the
app only reads the newest cached briefing and falls back to its SwiftData cache
offline. Keep generation on that side of the line.

- `SupabaseFunctions/` — Edge Functions: `_shared/rss.ts`, `gemini.ts`,
  `clustering.ts`, `briefingValidation.ts`, `cardArt.ts`, and the read API in
  `briefings-api/`
- `supabase/migrations/` — schema and the seed feed list
- `Shared/Models/` — `Briefing`, `BriefingTag`, `Persona`
- `Shared/Services/` — `BriefingService` (fetch), `BriefingCache` (SwiftData
  `@Model` offline copy), `TodayBriefingViewModel`, `AppConfig`, `Entitlements` +
  `RevenueCatEntitlementStore`, `StoreService`, `ReviewPromptTracker`
- `Sideline/Views/` — `TodayBriefingView` with `BriefingDeck`, `PersonaRail`,
  `FreshnessFooter`, plus onboarding, paywall and settings

## Rules that hold everywhere
- **Four personas, one free.** `Persona` is `cocktailParty`, `sportsTalkForMoms`,
  `officeWatercooler`, `dateNight`; `Persona.isFree` is true for
  `cocktailParty` only, and `EntitlementProviding.canUse(persona:)` in
  `Entitlements.swift` is the check to call. `OnboardingView` and `PersonaRail`
  still inline the same `!persona.isFree && !isPro` test; prefer `canUse`. Paywall
  wording lives in `Sideline/copy/PAYWALL.md`: one room free, Pro is all four
  contexts and fresher briefings.
- **Config comes from `Config/Secrets.xcconfig`, which is not committed.**
  `Config/Secrets.example.xcconfig` lists the keys (`SIDELINE_SUPABASE_URL`,
  `SIDELINE_SUPABASE_ANON_KEY`, `SIDELINE_REVENUECAT_API_KEY`); `AppConfig` reads
  them from the bundle, or from the environment in tests. A missing file gives a
  build with no backend, not a compile error.
- **Briefings are refreshed three times a day** by
  `.github/workflows/sideline-cron.yml` (14:00, 19:00 and 23:00 UTC), which calls
  the function with `x-cron-secret`. Backend env keys are listed in `README.md`.
- **Every briefing is source-cited and written for a non-fan.** No team, league
  or athlete imagery in the app's own art (`CardArt`), and nothing should read as
  a prediction or a betting angle.
- **Review funnel:** `ReviewPromptTracker.recordPositiveMoment()` from
  `TodayBriefingViewModel` after a briefing is read. App Store ID above.
- The marketing site is this repo's `docs/`, served by GitHub Pages from
  `jackwallner/sports`. Keyword reasoning is in `aso-plan.md`.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
review funnel, gotchas): always-loaded global CLAUDE.md + the `ios-dev` skill.
