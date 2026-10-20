# Gist (The Sideline) Project Guide

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
- `Sideline`: `com.jackwallner.sports`
- `Shared`: `.shared` (DTOs, services, caching, entitlements; the tests import it)
- `SidelineTests`: `.tests`, `SidelineUITests` — `.uitests`
- No App Group, no widget or watch target

## Architecture
**The app never calls Gemini.** Scheduled backend jobs pull curated RSS feeds,
generate strict JSON briefings, validate them, and store them in Supabase; the
app only reads the newest cached briefing and falls back to its SwiftData cache
offline. Keep generation on that side of the line.

- `SupabaseFunctions/`: Edge Functions: `_shared/rss.ts`, `gemini.ts`,
  `clustering.ts`, `briefingValidation.ts`, `cardArt.ts`, and the read API in
  `briefings-api/`
- `supabase/migrations/`: schema and the seed feed list
- `Shared/Models/`: `Briefing`, `BriefingTag`, `Persona`
- `Shared/Services/`: `BriefingService` (fetch), `BriefingCache` (SwiftData
  `@Model` offline copy), `TodayBriefingViewModel`, `AppConfig`, `Entitlements` +
  `RevenueCatEntitlementStore`, `StoreService`, `ReviewPromptTracker`
- `Sideline/Views/`: `TodayBriefingView` with `BriefingDeck`, `PersonaRail`,
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
- **Briefings are refreshed three times a day** by pg_cron in Supabase
  (`supabase/migrations/20261013000000_pg_cron_pipeline.sql`, 14:05, 19:05 and
  23:05 UTC, one persona every 4 minutes after ingest), which calls the functions
  with `x-cron-secret` read from Vault. Check runs in `cron.job_run_details` and
  `net._http_response`. `.github/workflows/sideline-cron.yml` is manual only.
  Backend env keys are listed in `README.md`.
- **Every briefing is source-cited and written for a non-fan.** No team, league
  or athlete imagery in the app's own art (`CardArt`), and nothing should read as
  a prediction or a betting angle.
- **Ratings:** no in-app rating question (App Review 5.6.1). After a
  briefing loads from a refresh or room switch, or the deck reaches its
  "Your move" card, `TodayBriefingView` calls the system `requestReview()`
  about 3.5s later if no sheet is up and the deck is not on the rooms pitch
  card (from the 2nd launch, 30-day cooldown). A source sheet's dismissal
  retries a blocked ask; a paywall or Pro preview never does. Settings has
  separate "Send Feedback" and "Rate Gist" rows. App Store ID above.
- The marketing site is this repo's `docs/`, served by GitHub Pages from
  `jackwallner/sports`. Keyword reasoning is in `project-docs/marketing/aso-plan.md`.

## Path rules
- `.claude/rules/android.md` (`android/**`): the Kotlin/Compose port, its
  build and emulator commands, keys, and Play state.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
ratings, gotchas): the global agent rules + the `ios-dev` skill.
