# Gist audit823

Date: 2026-08-23

Scope: Gist in `/Users/jackwallner/sports` only. This is a read-only audit of the local source, configuration, repository documentation, App Store metadata, public marketing pages, purchase surfaces, and the app and content pipeline evidence available in the repository and audit context. The only permitted write for this task is this file. No app code, configuration, scripts, metadata, website, or documentation source was changed.

## Executive assessment

Gist has a clear, differentiated promise: give a non-fan a short, usable sports talking point. The free-to-Pro value ladder is understandable in code, the native paywall has real purchase disclosures, the app supports restore and offline cached content, and the review prompt is deliberately delayed until positive moments. The main risks are not a lack of ideas. They are inconsistent product truth, weak conversion instrumentation, and release reliability gaps that can make a good storefront promise lead to a confusing or empty first session.

The highest priority items are:

1. Resolve the five-context Local Team promise. The website and backend support five contexts, while the native iOS model and UI expose four and the native client does not query local teams.
2. Block the production app from silently falling back to `SampleBriefingService` and demo/local entitlement behavior when release configuration is missing.
3. Make ASC metadata validation cover all 50 localized listings and retire or update the stale locale generator. The current all-locale keyword inventory has 27 files over Apple's 100-character keyword limit, while the validator checks only `en-US`.
4. Fix acquisition assets that are objectively broken or duplicated: the landing page's JSON-LD screenshot URL returns 404, and two displayed screenshot files are byte-identical despite different labels.
5. Add a measurable trial and purchase funnel. Current RevenueCat integration records paywall impressions only. It does not identify the entry surface, selected package, eligibility result, trial start, purchase outcome, restore outcome, or first Pro value.
6. Add release and content watchdog coverage before the next acquisition push. No in-app crash or hang telemetry integration was found, and the content workflow has retries but no repository-defined alert or freshness gate.

## Evidence standard and confidence

Each finding distinguishes evidence from inference:

- `E-local`: directly observed in the checked-out repository.
- `E-web`: directly observed through read-only HTTP inspection of the public pages on 2026-08-23.
- `E-context`: status or dashboard evidence already available in the audit context, not re-created as a local file.
- `I`: an implication or hypothesis that needs validation with ASC, RevenueCat, production logs, or a runtime test.

No current Gist download, trial-start, conversion, retention, crash-rate, review-count, or revenue dataset was captured in this rerun. Recommendations that depend on those metrics are measurement plans, not claims about current performance.

## Product and release identity

| Fact | Evidence | Assessment |
| --- | --- | --- |
| User-facing product name | `Sideline/Info.plist` displays `Gist`; current storefront and website title are `Gist: Sports Made Simple`. | Good user-facing rebrand, but internal names remain `Sideline`. Agent docs need an explicit mapping. |
| Xcode project and scheme | `project.yml`, `CLAUDE.md`, and source symbols use `Sideline`. | This is technically fine, but stale agent-facing prose calls the product The Sideline. |
| Bundle identifier | `project.yml`, `fastlane/Appfile`, and `Sideline/Info.plist`: `com.jackwallner.sports`. | Consistent locally. Verify against the ASC record before every upload. |
| App Store ID | `Shared/Utilities/AppStoreReviewLinks.swift:6`, `scripts/asc-submit-for-review.py`, and website links: `6770138156`. | Consistent locally and on the public pages. |
| Local build | `project.yml:18-19`: marketing version `1.1.2`, build `53`. | Consistent with the generated project files. |
| ASC context snapshot | The signed-in ASC app list available in the audit context showed `Gist: Sports Made Simple`, app ID `6770138156`, iOS `1.1.2`, status `Ready for Distribution`, observed 2026-08-23. | Treat as current context evidence, but refresh from ASC before release decisions. |
| Local ASC state snapshot | `scripts/.asc-state.json`: draft `1.1.2`, live `1.1.0`, updated `2026-07-28T05:00:04Z`. | Stale relative to the ASC context snapshot. Any automation consuming this file can make the wrong release decision. |
| Worktree before audit | `git status --short --branch`: `main...origin/main`, no existing `audit823.md`. | Clean starting point. This audit does not authorize a commit or push. |

### Release identity finding: stale ASC state

Priority: P1, release operations.

Evidence: `scripts/.asc-state.json` still says `liveVersion: 1.1.0`, even though the audit context showed version `1.1.2` ready for distribution. The state file has not been updated since 2026-07-28.

Inference: release scripts or an agent may treat 1.1.2 as a draft-only version, or may compare against the wrong live baseline when evaluating a regression.

Recommendation: make the state file generated output with a visible source timestamp, or stop using it as a decision source. The release gate should query ASC and record app ID, live version, editable version, build number, status, and last successful upload. Fail closed if the snapshot is older than a configurable age.

Validation:

1. Pull the current ASC app and version records for `6770138156`.
2. Compare live version, editable version, build, and status with `project.yml`.
3. Run the release check once while ASC is unavailable and confirm it reports `unknown`, not a false match.

## P0 findings

### P0-1: The storefront promises Local Team, but native Gist does not expose it

Evidence:

- `docs/index.html:627-649` advertises “All 5 contexts” and a Local Team feature.
- `SupabaseFunctions/_shared/types.ts:1-24` includes `local_team` in the backend persona and Pro persona sets.
- `supabase/migrations/20260516214000_initial_sideline_schema.sql:3-8` includes a `local_team` enum, and `20260523000000_local_team_briefings.sql` adds `team` fields and an index.
- `SupabaseFunctions/briefings-api/index.ts:10-29` accepts `persona`, `scope`, and `team`, and filters local requests by team.
- `Shared/Models/Persona.swift:3-86` has only `cocktail_party`, `sports_talk_for_moms`, `office_watercooler`, and `date_night`.
- `Shared/Services/Entitlements.swift:3-36` gates the three non-free native personas as Pro, with no Local Team case.
- `Sideline/Views/Components/PersonaRail.swift` and `BriefingDeck.swift` render `Persona.allCases`, so the missing native enum case is missing from onboarding, the rail, locked previews, and the rooms card.
- `Shared/Services/BriefingService.swift:27-85` directly queries PostgREST using persona and scope. It has no native Local Team model or `team` query path.
- `Sideline/Views/PaywallView.swift:215` and related paywall copy claim four rooms, while the landing page claims five contexts.

Assessment: this is a product truth failure, not merely stale copy. A user who downloads from the website or App Store and looks for Local Team cannot find it. If the backend's local-team path is intended to be live, the native client is incomplete. If it is not intended to be live, the website and related strategy documents are selling an unavailable feature.

Required decision:

- Option A, ship Local Team: add a native persona/team model, team selection and persistence, local scope requests, entitlement handling, onboarding or post-first-value discovery, team-specific cache keys, team-aware analytics, and scheduled generation. Test empty, invalid, renamed, and unsupported teams.
- Option B, defer Local Team: remove the claim from the landing page, metadata source files, screenshots, paywall copy, terms or support references where applicable, and any Pro feature list. Keep backend code only if it is explicitly marked dormant and excluded from release promises.

Do not run an acquisition experiment on a promise that the app cannot fulfill. Make one canonical count for contexts, rooms, and refreshes, then derive website, ASC, paywall, onboarding, and agent documentation from it.

Validation:

1. On a clean device, enumerate every persona visible in onboarding, the persona rail, the rooms card, and the paywall.
2. Query a local-team briefing through the same client path used by iOS, not only the Edge Function.
3. If shipping it, verify a selected team survives relaunch and is included in cache and network keys.
4. If deferring it, grep the repository and public HTML for `Local Team`, `local_team`, and “5 contexts”; every remaining occurrence must have an explicit backend-only or historical label.
5. Compare the final count in ASC screenshots, description, website JSON-LD, paywall, and terms.

### P0-2: Release can silently ship sample content and local entitlements

Evidence: `Sideline/SidelineApp.swift:20-37` selects `SupabaseBriefingService` only when runtime configuration is present. Otherwise it selects `SampleBriefingService` and sets `isDemo = true`. `Sideline/SidelineApp.swift:39-66` configures RevenueCat only outside the simulator and falls back to `LocalEntitlementStore` when RevenueCat is unavailable.

Inference: a missing `Secrets.xcconfig`, missing Supabase values, wrong build setting, or stripped RevenueCat configuration can produce a release that appears to work but serves static sample data and cannot exercise the real purchase path. The debug/demo behavior is useful for development, but there is no evidence of a Release-only fatal configuration gate.

Impact:

- First-session content can be stale, synthetic, or contain `example.com` sources from `Briefing.sample` in `Shared/Models/Briefing.swift:146` onward.
- Acquisition traffic can be counted as a content failure while the app reports no server error.
- A user can reach a local Pro state in a build that is not connected to production RevenueCat.
- QA can pass the app using debug fallback and miss a release configuration failure.

Recommendation:

- In Release, fail the build or show a controlled, explicit configuration error if the Supabase and RevenueCat production settings are missing. Do not silently select sample content.
- Keep simulator and debug safety behavior, including the current guard that avoids the production RevenueCat key on simulator runs.
- Add a CI archive smoke test that inspects the Release bundle for required non-secret configuration markers and launches a sanitized build against a test backend.
- Keep a deliberately separate demo target or launch argument so agents can use sample content without making it a release fallback.

Validation:

1. Build Release with valid configuration and assert the first request reaches the configured backend.
2. Build Release with each required configuration value removed and assert a visible failure plus a nonzero CI check.
3. Confirm `Briefing.sample` and `LocalEntitlementStore` remain reachable only in debug/demo paths.
4. Search the archive for sample strings, `example.com`, and demo labels.
5. Run a clean install with RevenueCat unavailable and verify the app does not present a false successful purchase state.

### P0-3: ASC metadata automation can reject or overwrite localized listings

Evidence:

- `fastlane/metadata` contains 50 locale directories, plus `review_information`.
- The existing `scripts/validate-asc-metadata.py` checks only `fastlane/metadata/en-US`.
- An all-locale read-only character scan found 27 keyword files over 100 characters: `sk` 101, `pl` 104, `vi` 129, `sv` 101, `he` 108, `or-IN` 249, `ja` 109, `el` 181, `ca` 104, `mr-IN` 250, `ar-SA` 140, `ru` 189, `kn-IN` 256, `gu-IN` 199, `ro` 105, `uk` 185, `ml-IN` 259, `hu` 109, `hi` 253, `ko` 110, `fi` 104, `ta-IN` 265, `te-IN` 262, `bn-BD` 242, `ur-PK` 140, `th` 223, and `pa-IN` 236.
- `scripts/aso-locale-content.json` contains old “The Sideline” descriptions and is consumed by `scripts/aso-apply-locale-optimizations.py`, making it a likely future overwrite source.
- `docs/app-store-metadata.md`, `docs/astro-aso-setup.md`, and `docs/localization-aso.md` describe old names, old draft versions, or old product claims.

Assessment: the current en-US validator passing is not evidence that the listing is safe. The localized metadata inventory is internally inconsistent and the generator has an old brand/product source.

Recommendation:

- Expand validation to every locale and every ASC field limit, including name, subtitle, keywords, promotional text, and description.
- Validate Unicode character counts using the same counting behavior expected by ASC, not only shell byte counts.
- Detect blank marketing URLs, invalid URLs, duplicate keyword tokens, stale product names, old bundle or app IDs, unsupported context claims, and missing release notes.
- Mark one file as the source of truth. Either regenerate `fastlane/metadata` from it or retire the generator. Do not leave a stale JSON file that an agent can use to restore the old brand.
- Add a dry-run diff against the current ASC listing before upload.

Validation:

1. Run the validator over all 50 locale directories.
2. Fail CI on any limit violation, old brand string, or unsupported product claim.
3. Run the upload command with `--dry-run` or an equivalent API diff and review every changed locale.
4. Pull ASC after upload and compare the returned localization fields with the repository source.

## Acquisition and download conversion

### Current storefront strengths

Evidence:

- `fastlane/metadata/en-US/name.txt`: `Gist: Sports Made Simple`.
- `fastlane/metadata/en-US/subtitle.txt`: `Sports in 5 Minutes a Day`.
- The en-US keyword line is within the 100-character limit according to the current validator.
- The en-US description explains the free Cocktail Party briefing, Pro contexts, refresh value, eligible one-week trial, auto-renewal, and links to support, privacy, and terms through the metadata URL fields.
- `docs/index.html` has current Gist title/description metadata, App Store ID `6770138156`, a canonical URL, a visible App Store CTA, and JSON-LD software metadata.
- `docs/privacy-policy.html` and `docs/terms.html` were observed publicly with August 17, 2026 update dates.

These are good foundations for a simple “download, read one useful briefing, then decide” acquisition story.

### Acquisition finding A1: the current listing, website, and code describe different products

Evidence:

- The website claims five contexts and Local Team.
- Native `Persona.allCases` has four contexts and no Local Team.
- `PaywallView` says “4 rooms, 4 briefings a day” in one benefit and also uses three-times-daily freshness language.
- `fastlane/metadata/en-US/description.txt` describes monthly and yearly Pro subscriptions and the trial, but does not mention the lifetime product.
- The website and terms describe a one-time lifetime purchase.
- `Sideline/copy/PAYWALL.md` describes all four current native contexts and monthly/annual plans, but omits the lifetime plan that the current paywall renders.

Inference: a user may see a different product count or offer inventory depending on whether they arrive through the website, the App Store listing, the paywall, or an agent-generated support answer. This can lower trust and create support contacts even if checkout technically works.

Action:

1. Decide the canonical inventory: number of contexts, number of free contexts, refresh windows, subscription periods, and lifetime availability.
2. Create a small source-of-truth object or generated content file for those facts.
3. Generate or manually synchronize paywall copy, website copy, ASC description, support, terms, and test fixtures from that source.
4. Add a consistency scanner that flags conflicting counts, plan names, prices, app ID, bundle ID, and brand names.

Validation: a table-driven test should assert that the same canonical facts appear in `PaywallView`, `docs/index.html`, `fastlane/metadata/en-US/description.txt`, `docs/terms.html`, `docs/support.html`, and the current design handoff.

### Acquisition finding A2: landing page structured data has a broken screenshot URL

Evidence: `docs/index.html` JSON-LD references `https://jackwallner.github.io/sports/appstore-screenshot-01.png`. A read-only HTTP HEAD returned 404 for that path on both the GitHub Pages and portfolio hosts. The actual local screenshot path is `docs/screenshots/store-1-deck-lead.png`, which returned 200 when served at the corresponding public path.

Impact: search engines, link previews, and automated acquisition checks can receive a missing image even though the page visually has screenshots. This also makes future site audits noisy.

Recommendation: point JSON-LD to a canonical public asset that exists, preferably the same generated asset used in the page, and add a CI link check for every `og:image`, JSON-LD image, favicon, App Store link, support link, privacy link, and terms link.

Validation:

1. Check every public URL in HTML, JSON-LD, sitemap, and CSS for a 2xx response.
2. Validate the JSON-LD as `SoftwareApplication` and confirm the app ID, name, version, offers, and image all match the current product source.
3. Re-run the check after GitHub Pages deployment, not only against local files.

### Acquisition finding A3: two public screenshots are byte-identical

Evidence: `docs/screenshots/store-3-backstory.png` and `docs/screenshots/store-4-personas.png` have the same SHA-256 digest and compare byte-for-byte equal. Both are 720 x 1564. The HTML labels them as different storefront states. The five `fastlane/screenshots/en-US` files are distinct, so the likely issue is the website asset set or copy step.

Impact: a prospective user sees fewer distinct product capabilities than intended. The personas screenshot is particularly important because it should explain the locked-room upgrade path.

Recommendation: replace the duplicate with the intended personas capture, then add a semantic screenshot manifest containing filename, screen purpose, dimensions, and expected perceptual hash. A simple exact-hash check is enough to catch accidental duplicates, while manual review confirms the screen content.

Validation: compare all website screenshot hashes, dimensions, alt text, and visible claims with the actual image. Test at mobile width and on the canonical host.

### Acquisition finding A4: 50 localized listings are paired with English-only app UI

Evidence: the repo has 50 ASC metadata locale directories, but the native user-facing strings in `OnboardingView`, `PaywallView`, `TodayBriefingView`, `SettingsView`, and the review flow are inline English strings. I found no matching localized UI resource set for these screens, and the screenshot inventory is only under `fastlane/screenshots/en-US`.

Inference: localized store visitors can download an English-only experience after reading localized metadata. That may be intentional for keyword testing, but it should be a conscious localization strategy rather than an accidental expectation mismatch.

Options:

- Localize the product and provide localized screenshots for the highest-value locales.
- Reduce or pause localized listings until the product supports them.
- Keep the listings but make the rollout explicitly experimental and measure conversion, refund, support, and early retention by locale.

Validation: for each enabled locale, compare listing language, screenshot language, onboarding language, paywall language, system locale behavior, and source content language. Pull ASC conversion by locale before deciding whether the broad localization footprint is earning its maintenance cost.

### Acquisition finding A5: marketing URL is blank in every locale

Evidence: all 50 `fastlane/metadata/*/marketing_url.txt` files are blank. Support and privacy URLs are populated consistently with the GitHub Pages domain.

Inference: blank marketing URLs may be valid for ASC, but they remove a direct listing-to-site path and a possible acquisition attribution surface. The canonical website already exists.

Recommendation: either populate the marketing URL with the canonical landing page and a documented attribution convention, or record in the source-of-truth documentation that the field is intentionally blank. Do not silently leave it ambiguous.

Validation: check whether ASC displays the marketing URL in each storefront and whether it creates any useful referral signal. Keep support and privacy URLs separate.

### Acquisition finding A6: static price claims need a source check

Evidence: `docs/index.html` JSON-LD hardcodes monthly `$5.99`, yearly `$29.99`, and lifetime `$59.99`. The paywall renders RevenueCat package prices dynamically through `StoreService`. Current Gist-specific RevenueCat package and territory price data was not captured in this rerun.

Inference: the site can become wrong after a price, territory, tax, or offer change even if the in-app checkout remains correct. Static JSON-LD offers are particularly likely to be consumed without the surrounding “prices vary by region” copy.

Recommendation: remove hardcoded price values from structured data unless they are automatically generated from an approved price source. If prices remain, make the site build fail when the configured values differ from the approved RevenueCat or ASC export.

Validation: for US and at least three non-US storefronts, compare site copy, ASC product pricing, RevenueCat package prices, paywall display, terms wording, and the final charged amount in StoreKit sandbox.

## Activation, onboarding, and first value

### Current activation path

Evidence from `Sideline/Views/OnboardingView.swift`, `TodayBriefingView.swift`, `BriefingDeck.swift`, `ProPreviewSheet.swift`, and `PaywallView.swift`:

1. A new install sees a two-page onboarding flow.
2. The first page says “Sports, made simple” and frames the product as a five-minute briefing.
3. The second page selects a persona. `Persona.allCases` renders four native personas, with Cocktail Party free and the others locked for Pro.
4. Tapping “See today's briefing” stores the selected persona and completes onboarding. It does not show a trial or paywall.
5. The user loads a national Cocktail Party briefing through `TodayBriefingViewModel.load`.
6. The deck presents a lead card, bullet cards, a question card, and a rooms card for free users.
7. A locked persona can be reached from the persona rail or rooms card. The route is `ProPreviewSheet`, then `PaywallView`.
8. A free refresh limit presents a separate paywall surface. The CTA text is “Try Pro Free” only when RevenueCat intro eligibility says an offer is available; otherwise it says “See Pro”.

This is a sensible free-first activation model, but the paywall is intentionally late and the core activation funnel is not measured.

### Activation finding B1: the onboarding trial surface was removed and is now an experiment gap

Evidence: `Sideline/Views/OnboardingView.swift:7-188` contains only value proposition and persona selection. The current flow has no trial page or paywall after the first free briefing. Historical commit `585c55d` removed a third trial page and onboarding paywall while improving storefront and trial conversion. Historical `archive/uc528.md` also identified an onboarding trial page as a high-priority opportunity.

Inference: removing an early paywall may improve trust and first-value completion, but it also means a new user who is ready to try Pro must discover a locked room, rooms card, or refresh limit. The current implementation cannot tell whether the missing trial surface is helping or suppressing trial starts.

Recommendation: retain the current flow as the control and test one post-first-value variant:

- Control: finish the free briefing with no modal.
- Variant A: show a single, dismissible “Try Pro with all rooms” card after the user flips the question card or reaches the end of the deck.
- Variant B: show the existing Pro preview followed by the paywall after the user taps the rooms card.
- Variant C: show the paywall directly from the first locked room, with a “See how it works” secondary action to preserve education.

Primary metric: eligible trial starts per activated user. Secondary metrics: first briefing completion, time to first Pro value, paywall dismissal, free return on day 2, purchase conversion, refund/cancel rate, and support contact rate. Guardrail: no material drop in first briefing completion or day-1 retention.

Validation: use a stable experiment assignment, persist the arm through reinstall only if the intended product policy allows it, and exclude existing Pro customers. Verify that non-eligible users see accurate non-trial copy.

### Activation finding B2: the locked-room path has an avoidable extra step

Evidence: `TodayBriefingView` routes locked rooms to `ProPreviewSheet`, and that sheet's CTA opens `PaywallView`. The preview explains value and says the room gets its own stories, but the user must make two modal decisions before seeing price and trial details.

Inference: preview education may improve informed conversion for cold users, but a returning user who already selected a locked persona may experience it as friction. The current code has no surface-level conversion data to decide.

Recommendation: test direct paywall versus preview-first by entry surface. Keep preview-first for the first locked-room tap, and direct paywall for a repeated tap or for users who already completed a free briefing, if the data supports that policy. Make the preview CTA label explicit about the next step, for example “See plans and trial”.

Validation: compare `locked_persona_preview_shown`, `locked_persona_paywall_shown`, `paywall_purchase_started`, `trial_started`, and dismiss rates by surface and user state.

### Activation finding B3: the first value proposition is strong but lacks a completion signal

Evidence: onboarding says “What happened. Why it matters. One thing to say. Catch up on the sports everyone is talking about in five minutes a day.” `TodayBriefingViewModel` can load and cache content, and `BriefingDeck` has a swipe hint, but there is no explicit first-value event or completion marker.

Inference: product and paywall experiments cannot distinguish a user who opened the app from one who actually read enough to understand the promise.

Recommendation: define first value as a small, observable sequence, for example: briefing loaded, lead card viewed, at least two story cards viewed, question card viewed or deck completed. Instrument it in a privacy-conscious first-party event sink or a low-cardinality summary attribute. Do not use a single swipe as proof of comprehension.

Validation: run a new-user session and confirm the event sequence survives offline fallback, relaunch, and a failed card-art request. Compare first-value rate with trial starts and day-1 return.

### Activation finding B4: demo content and real content can look too similar

Evidence: `Sideline/SidelineApp.swift` sets `isDemo`, and `TodayBriefingView` shows a demo banner when that flag is true. `Shared/Models/Briefing.sample` includes synthetic content and `example.com` URLs.

Assessment: the explicit banner reduces the risk of silent confusion in debug/demo mode, but the P0 release fallback can still expose it to real users if configuration is missing. The first-value test must include both valid production configuration and deliberately absent configuration.

## RevenueCat, trial, and purchase flow

### Current implementation map

Evidence: `Shared/Services/StoreService.swift` and `Sideline/Views/PaywallView.swift`.

- RevenueCat is a Swift Package dependency in `project.yml:28-29`, versioned from the RevenueCat SPM repository.
- `StoreService.PackageKind` classifies annual, monthly, lifetime, and other packages by package type or identifier text.
- `CustomerInfo.sidelineProEntitlement` first looks for hardcoded entitlement ID `Sports Pro`, then falls back to the first active entitlement.
- `Offerings.sidelinePaywallOffering` prefers offering ID `default`, then `current`, then the first non-empty offering.
- `StoreService` fetches offerings, products, customer information, and introductory eligibility.
- `trialAvailable` is derived from whether any product with an introductory discount is eligible.
- Purchase calls `Purchases.shared.purchase`, applies returned customer info, and maps cancelled, purchased, and pending states.
- Restore calls `Purchases.shared.restorePurchases` and applies the returned customer info.
- `PaywallView` tracks `Purchases.shared.trackCustomPaywallImpression` with surface-specific IDs.
- The current code search found no `setAttributes` calls, no RevenueCat custom attribute wrapper, and no purchase/trial/restore event stream.
- `RevenueCatEntitlementStore.swift` is a deprecated typealias to `StoreService`, which is harmless but can confuse agents looking for the current store abstraction.

RevenueCat project evidence available in the audit context showed a Gist production project with identifier `56682a14`. The exact live offering, product IDs, entitlement configuration, prices, trial eligibility results, experiment configuration, and current subscriber metrics were not captured in this rerun. They must be pulled before changing package copy or pricing.

### Purchase finding C1: hardcoded entitlement with a permissive fallback needs a release check

Evidence: `StoreService.entitlementIdentifier` is hardcoded to `Sports Pro`, and `CustomerInfo.sidelineProEntitlement` falls back to the first active entitlement if that identifier is absent.

Inference: the fallback protects a freshly configured project, but it can unlock Gist Pro for an unintended active entitlement if the dashboard contains multiple entitlements or a naming mistake. The comment says the current dashboard entitlement is Sports Pro, but no live dashboard verification is in this audit file.

Recommendation:

- Verify the exact production entitlement identifier in RC project `56682a14`.
- Prefer explicit entitlement matching in Release. If a fallback is retained for debug or migration, log a high-severity diagnostic and make the release check fail when the expected entitlement is absent.
- Add tests with unrelated active entitlements, lifetime purchases, expired subscriptions, and multiple active entitlements.

Validation: use StoreKit sandbox or a non-production RC project with controlled entitlement names. Confirm only the intended entitlement unlocks `isPro`.

### Purchase finding C2: package selection is too dependent on text classification

Evidence: `StoreService.PackageKind` uses RevenueCat package types first and product/package identifier string matching for annual, monthly, lifetime, and other. `PaywallView` displays every package returned by the selected offering.

Inference: a dashboard package identifier that does not contain the expected text can be classified as `.other`, and a new package can appear without deliberate copy or experiment treatment. Showing every package also makes a dashboard change a product UX change.

Recommendation:

- Define an explicit approved product catalog mapping product ID to display kind, entitlement behavior, trial eligibility, and experiment role.
- Fail or hide unknown packages in Release rather than silently displaying them as a new plan.
- Log the offering ID, package IDs, product IDs, and classification at paywall load, without logging customer-identifying data.

Validation: test renamed product IDs, a new `.other` package, missing annual, missing monthly, lifetime only, and an offering with no packages.

### Purchase finding C3: trial eligibility has no visible failure state

Evidence: `StoreService` stores an eligibility map and derives one boolean `trialAvailable`. `PaywallView` changes CTA and reassurance copy based on that boolean. There is no distinct UI state for “eligibility request failed”, and no current funnel event records the eligibility result or reason.

Inference: a network or StoreKit failure can look like a user who is simply ineligible. A trial-positive experiment may appear to underperform because eligibility was not loaded, not because users rejected the offer.

Recommendation:

- Track `eligible`, `ineligible`, `unknown`, and `not_applicable` separately.
- If eligibility is unknown, show price and purchase controls without promising a trial, and make the state observable in diagnostics.
- Decide whether a short retry is appropriate before presenting the paywall. Do not block the paywall indefinitely.
- Make copy distinguish “This Apple Account is not eligible” from “Trial information is unavailable”.

Validation: airplane mode, StoreKit error, sandbox eligible customer, sandbox ineligible customer, restored customer, lifetime customer, and a product with no introductory offer.

### Purchase finding C4: lifetime and subscription management behavior need an explicit matrix

Evidence: `PaywallView` renders annual, monthly, and lifetime cards when returned. `SettingsView` shows Manage Subscription only when `isPro && store.hasActiveSubscription`; `StoreService.hasActiveSubscription` excludes product IDs containing `lifetime`.

Assessment: the lifetime management behavior appears intentional, but it needs a visible explanation so lifetime purchasers do not interpret the missing Manage Subscription row as an error. The App Store description currently omits lifetime while terms and website include it.

Validation matrix:

| State | Expected Settings action | Expected paywall state | Expected analytics |
| --- | --- | --- | --- |
| Trial active | Manage subscription, trial end copy | Trial copy and eligible package state | Trial active, source surface |
| Monthly active | Manage subscription | Current plan marked or purchase guarded | Active subscription |
| Annual active | Manage subscription | Current plan marked or purchase guarded | Active subscription |
| Lifetime active | No subscription manager needed, explain lifetime | Lifetime ownership reflected | Lifetime entitlement |
| Expired | Restore or subscribe | Accurate eligible/ineligible state | Expired, no false Pro |
| Pending | Clear pending message | Disable duplicate purchase | Pending outcome |
| Restored | Pro restored | Paywall dismisses or reflects ownership | Restore success |

### RevenueCat custom attributes to add

Use a small wrapper in `StoreService` so simulator and non-RevenueCat builds remain safe. Attributes are snapshots, not a substitute for an event stream. Overwrite them at state transitions and avoid raw email, arbitrary text, or high-frequency card-level data.

| Attribute | Values | Set or update at | Use |
| --- | --- | --- | --- |
| `app_build` | `1.1.2-53` | Store initialization and app launch | Segment release regressions. |
| `paywall_surface` | `locked_persona`, `rooms_card`, `refresh_limit`, `onboarding`, `settings` | Immediately before paywall impression | Compare conversion by entry point. |
| `paywall_context` | persona raw value or `none` | Same point as surface | Identify which value proposition created intent. |
| `paywall_variant` | Stable experiment arm | Before impression | Connect native layout or copy experiment to outcomes. |
| `selected_package` | `monthly`, `annual`, `lifetime` | Before purchase call | Compare plan choice and failures. |
| `intro_eligibility` | `eligible`, `ineligible`, `unknown`, `not_applicable` | After eligibility check | Separate demand from StoreKit failure. |
| `onboarding_state` | `not_started`, `completed`, `first_briefing_loaded`, `first_value` | On each milestone | Measure the activation gate. |
| `selected_persona` | Native raw value | `TodayBriefingViewModel.select` and app launch | Segment product value and content failures. |
| `briefing_state` | `online`, `cached`, `stale`, `failed` | After each load | Correlate content reliability with conversion. |
| `briefing_count_bucket` | `0`, `1`, `2-3`, `4+` | At most once per meaningful state change | Approximate product engagement without event history. |
| `last_restore_result` | `success`, `no_entitlement`, `failed` | After restore | Diagnose support-heavy restore cases. |
| `review_prompt_bucket` | `not_eligible`, `eligible`, `shown`, `feedback`, `store_link` | At prompt state changes | Compare review timing and conversion tradeoffs. |

If Local Team ships, add a normalized `team_selection_state` such as `none`, `selected`, or `unsupported`, rather than sending arbitrary team text by default. Do not add attributes that imply collection of data the product does not need. The requested audit intentionally does not assess the separate RevenueCat privacy-label consistency question.

### Events that should not be forced into RevenueCat attributes

Use a first-party or privacy-reviewed event sink for history and sequence:

- `app_opened`
- `onboarding_completed`
- `briefing_load_started`, `briefing_load_succeeded`, `briefing_load_failed`
- `first_value_completed`
- `persona_locked_tapped`
- `pro_preview_shown`, `pro_preview_cta_tapped`
- `paywall_impression`
- `paywall_plan_selected`
- `purchase_started`, `purchase_succeeded`, `purchase_cancelled`, `purchase_pending`, `purchase_failed`
- `restore_started`, `restore_succeeded`, `restore_empty`, `restore_failed`
- `trial_started`, `trial_converted`, `trial_cancelled`, `subscription_expired`
- `review_prompt_shown`, `review_yes`, `review_no`, `review_maybe_later`, `write_review_opened`, `feedback_opened`

RevenueCat can provide transaction and entitlement truth. It should not be the only store for all UX events.

## Native paywall and A/B test opportunities

The current paywall has several controllable “nooks and crannies”. Every test must use a stable assignment, preserve Apple-required disclosure, keep restore accessible, and measure the same entry surface IDs currently used by `PaywallView` and `TodayBriefingView`.

| Test | Control | Variant | Hypothesis | Primary metric | Guardrails |
| --- | --- | --- | --- | --- | --- |
| Onboarding timing | No paywall after first free briefing | Dismissible post-first-value trial card or paywall | Showing Pro after value is understood increases eligible trial starts | Trial starts per activated user | First-value completion, day-1 return, dismiss rate |
| Locked room route | Preview sheet, then paywall | Direct paywall with preview as secondary action | Returning users need less modal friction | Paywall-to-purchase rate | Preview engagement, refunds, support contacts |
| Rooms card CTA | “Try every room free” or existing copy | “See today’s Pro rooms” plus explicit trial detail | Specific outcome language reduces uncertainty | CTA to paywall and trial start | Free deck completion, accidental taps |
| Plan default | Annual selected by default | Monthly selected, or neutral choice with annual value callout | Default framing affects plan choice without reducing total value | Net revenue per paywall view and trial starts | Cancellation, refund, annual share |
| Lifetime placement | Secondary lifetime card | Lifetime shown as a clear alternative or lower emphasis | Users who reject recurring billing may convert lifetime | Lifetime purchase rate | Subscription conversion, revenue per visitor |
| Trial copy | “X days free, then price” | Same price plus explicit first charge date and reminder language | Specific billing timing improves trust | Trial start rate | Refunds, support, cancellation before charge |
| Benefit order | Rooms, refreshes, plain-English explanation | Start with the immediate first-session outcome, then breadth | Concrete value may beat feature inventory | Scroll-to-purchase and trial starts | Paywall load time, dismiss rate |
| Eligibility state | Generic Subscribe when trial unavailable | Explicit eligible/ineligible/unknown copy | Accurate state removes ambiguity | Trial CTA tap rate among eligible users | Purchase errors, support cases |
| Paywall context | Generic headline | Headline tied to locked persona or refresh limit | Contextual motivation improves relevance | Conversion by surface | Cross-surface consistency |
| Purchase disclosure layout | Fixed four-line disclosure area | Dynamic-height disclosure with no clipping | Better readability reduces hesitation and App Review risk | Purchase completion and support contacts | Dynamic Type, localization, review rejection |

Current surfaces to keep as explicit dimensions:

- `sideline_locked_room_paywall_<persona.rawValue>`
- `sideline_free_deck_rooms_paywall`
- `sideline_refresh_limit_paywall`
- any future onboarding surface ID

Before running tests, fix the product-count and refresh-count truth. An experiment cannot produce useful results if one arm promises a feature that another screen says is unavailable.

## Ratings and review funnel

### Current behavior

Evidence:

- `Shared/Services/ReviewPromptTracker.swift` requires at least 5 launches, at least 7 days since first open, and at least 3 positive moments. It applies a 120-day cooldown.
- `TodayBriefingView` calls the tracker after successful online content loads, persona selection, or refresh paths that record a positive moment. Cached or failed loads should not count as the same positive moment.
- `ReviewPromptSheet` first asks whether the user is enjoying Gist. A positive response shows a review pitch, a negative response opens feedback, and “Maybe later” can call the native `requestReview` path after dismissal.
- `Shared/Utilities/AppStoreReviewLinks.swift` constructs a direct App Store write-review URL for app ID `6770138156`.
- `SettingsView` exposes “Rate or Send Feedback” outside the passive prompt.
- Prompt state and outcome are stored in local `UserDefaults`; no remote prompt funnel or rating attribution was found.

Strengths:

- The prompt is delayed until the user has had repeated opportunities to receive value.
- Negative sentiment is routed to feedback instead of being pushed toward a public review.
- The user can still reach rating or feedback from Settings.

Gaps and risks:

1. There is no measurement of prompt shown, answer choice, direct review URL opened, native review request attempted, feedback link opened, or prompt dismissal.
2. A stored outcome can stop future passive prompts permanently for that device, even if the user later becomes highly satisfied after a product improvement.
3. The app cannot distinguish an online positive moment from a stale cache in a remote funnel.
4. Direct App Store write-review URLs can fail to open or behave differently by device/storefront. There is no visible fallback or observable open failure.
5. No current Gist rating count or rating trend was captured in this rerun. Any historical count in `marketing-strategy-2026.md` should be treated as stale until pulled from ASC by storefront and version.

Recommendations:

- Instrument the funnel events listed above, with a local queue and privacy-reviewed aggregate upload if needed.
- Keep the local throttle, but allow a new positive lifecycle after a major release or after a long cooldown if product policy permits.
- Test native request review versus direct write-review link for users who answer “Yes”, while keeping the negative feedback branch unchanged.
- Measure rating conversion by positive moment type: first successful briefing, completed deck, second-day return, persona switch, and successful Pro purchase.
- Add an ASC pull that reports rating count, average, recent rating distribution, storefront, app version, and review text themes. Do not use a historical marketing note as current evidence.

Validation:

1. Seed tracker states for launch count, age, positive moments, cooldown, and previous outcome.
2. Test first launch, failed load, cached load, successful online load, repeated positive moment, feedback, direct review link failure, and native review request.
3. Confirm the prompt never appears on top of a purchase error or an unresolved content failure.
4. Compare review prompt exposure with rating changes and support volume after a release.

## Content, briefing quality, and ongoing user experience

### Content request and cache path

Evidence:

- `Shared/Services/TodayBriefingViewModel.swift:3-157` requests the latest briefing for the selected persona and national scope, writes it to SwiftData, and falls back to cached content when a request fails.
- `Shared/Services/BriefingService.swift:27-85` directly queries the REST `briefings` table, orders by `generated_at`, and limits to one row.
- `Shared/Models/Briefing.swift:24-87` stores `generatedAt` and `expiresAt`.
- `Shared/Services/BriefingCache.swift:7-80` caches by persona and scope but does not enforce an expiration or purge an arbitrarily old cached row.
- `FreshnessFooter.swift:4-59` labels content older than 24 hours as stale, but the app does not appear to reject a row based on the stored `expiresAt` value.
- `SupabaseFunctions/briefings-api/index.ts` supports team-aware local queries, but the native client bypasses that function.

Findings:

1. The app can show cached content beyond its backend expiration. That is useful for offline resilience, but it should be explicit whether a stale row is allowed to appear as the main briefing.
2. All request failures collapse toward a friendly generic state. A decode failure, 401, 404, 5xx, timeout, and empty result need different operator signals even if the user copy is similar.
3. `URLSession.shared.data(for:)` in the briefing service does not show an explicit request timeout. A slow backend can hold the first-value funnel longer than intended.
4. Direct PostgREST access duplicates backend query logic and bypasses the team-capable Edge Function. This increases the chance that server and client behavior diverge.
5. The cache key does not currently have a team dimension because the native persona model has no Local Team. Shipping Local Team without changing this would serve the wrong cached briefing.

Recommendations:

- Define freshness policy by window. For example, show an expired row with a visible stale label only when offline, and never treat it as a successful online briefing.
- Add request timeout, retry policy, status classification, and a correlation ID.
- Return typed errors for empty, stale, unauthorized, server, decode, timeout, and offline cases.
- Prefer one server API path for filtering and future team support, or document why direct PostgREST is the intentional contract.
- Add a content health screen or operator query that reports latest row age, expiry, source count, and generation run for every persona and window.

### Generation and RSS pipeline

Evidence:

- `.github/workflows/sideline-cron.yml:3-56` schedules ingest and generation at UTC 14, 19, and 23, retries generation three times, and sets a 30-minute job timeout.
- The workflow's `PERSONAS` string contains four national personas: `cocktail_party`, `office_watercooler`, `date_night`, and `sports_talk_for_moms`. It does not generate Local Team targets.
- `SupabaseFunctions/generate-briefings/index.ts:60-145` validates generated output, stamps card art, inserts the briefing, and records generation run status. A card-art failure can fail the target after text generation.
- `SupabaseFunctions/_shared/briefingValidation.ts:8-152` checks required fields, bullet count, source count, URL shape, and text lengths, but not source freshness, duplicate stories, source quality, or whether `expires_at` is sensible.
- `SupabaseFunctions/ingest-rss/index.ts:7-137` records feed errors and durations but has no visible external alert path and no explicit per-fetch timeout.
- `SupabaseFunctions/README.md` describes cron usage and logs but does not establish an SLA or alert recipient.

Recommendations:

- Add a post-run health check for each expected persona and refresh window. Alert if a row is missing, too old, expired, low-source, or attached to a failed run.
- Treat card art as a best-effort decoration. Do not fail the entire briefing generation if text is valid and art can use a known fallback.
- Add source freshness, duplicate URL, source-domain, and content-window checks.
- Add explicit RSS and generation timeouts, and retain the last successful run timestamp.
- Make the expected target matrix generated from the same product configuration used by the app so a new persona cannot be advertised without a scheduled job.

### Card art and degraded UI

Evidence: `Sideline/Utilities/CardArt.swift:183-327` serializes downloads, uses a 60-second URL timeout, retries some 402 or 429 responses, and renders a gradient until an image arrives. `SupabaseFunctions/_shared/cardArt.ts` stamps hosted art during generation.

Inference: card art failures may not crash the app, but a serial 60-second chain can delay visual completion and blank or gradient cards can lower perceived quality. Because backend art stamping can also fail generation, a decorative dependency can affect both the content pipeline and the user experience.

Recommendations:

- Measure art request latency, success, fallback, HTTP status, and cancellation rate by build.
- Use a shorter per-image timeout and a bounded total deck budget.
- Ensure a valid static fallback or cached image is present for every card.
- Keep backend text generation independent from art generation and report art degradation separately.

### Accessibility and interaction quality

Evidence:

- `BriefingDeck.swift` provides accessibility labels and a one-time swipe hint.
- `PaywallView.swift:239-312` uses fixed disclosure sizing and `lineLimit(4)` around important billing text.
- The native strings are English-only and there is no evidence of a full Dynamic Type, VoiceOver, right-to-left, or localization test matrix.
- `SettingsView` uses `try?` for Manage Subscription, so a failure can be invisible to the user.

Recommendations:

- Replace fixed disclosure sizing with dynamic height and test the longest localized price and renewal copy.
- Give purchase failures, restore failures, and Manage Subscription failures a recoverable visible state with a retry or support action.
- Test large accessibility sizes, VoiceOver focus order across swipeable cards, Reduce Motion, bold text, dark mode, right-to-left layout, and very long localized product names.
- Confirm that the Swipe deck has an accessible non-gesture path to every story, source, question, and paywall action.

## Website, terms, privacy, and public consistency

### Public pages observed

Evidence from read-only HTTP inspection on 2026-08-23:

- `https://jackwallner.github.io/sports/` returned HTTP 200 and had a public update timestamp of 2026-08-17.
- `https://jackwallner.com/ios/sports/` returned HTTP 200 and had a public update timestamp of 2026-08-23.
- `docs/index.html` has a current Gist title, canonical and Open Graph metadata, App Store ID, visible download links, and hardcoded offers.
- `docs/privacy-policy.html` and `docs/terms.html` both identify Gist and show August 17, 2026 update dates.
- `docs/support.html` still says it was last updated May 25, 2026.
- `docs/sitemap.xml` has May 25, 2026 `lastmod` values even though the public pages changed in August.

### Consistency findings

1. Website says five contexts and Local Team; native app currently has four. This is P0-1.
2. Website, terms, and paywall include lifetime; en-US App Store description omits it; `Sideline/copy/PAYWALL.md` omits it. This can create confusion for users searching for the lifetime option.
3. Website JSON-LD prices are static and need a live price-source check.
4. JSON-LD screenshot URL is broken.
5. Website screenshot files contain a duplicate state.
6. Support page's stale update date weakens trust and may make agents think it is the current legal or product source.
7. Sitemap dates are stale and can reduce search freshness signals.
8. `docs/index.html` states “Fresh 3 times a day”, while paywall copy includes “4 briefings a day”. The intended daily count must be defined.
9. `docs/privacy-policy.html` says purchases are processed by Apple and verified by RevenueCat. This audit intentionally does not report the separate app-data-label or RevenueCat disclosure consistency issue because it was explicitly out of scope.

### Recommended source hierarchy

Use this hierarchy so an agent cannot select an old page by accident:

1. Current app behavior and production dashboard configuration for facts that must be true.
2. One maintained product facts file for counts, plans, prices, version, app ID, and URLs.
3. `fastlane/metadata` as the upload artifact, generated or reviewed from the product facts source.
4. Website and terms generated or manually checked against that source.
5. Dated strategy documents and design handoffs marked historical and moved under an archive path.

## Crash, regression, and watchdog requirements

### Current evidence

No in-app `MetricKit`, Crashlytics, Sentry, Firebase crash, `os_signpost`, or equivalent crash/hang monitoring integration was found in the inspected source. App Store Connect diagnostics and Xcode Organizer remain possible external sources, but no repository-defined polling or alert script is present. The GitHub workflow retries generation and fails the job on unsuccessful requests, but no email or notification configuration is defined.

This means the repo currently has no demonstrated path from “a live user crashes” to an operator alert. A Mac script can poll an external source, but it cannot discover an individual crash immediately unless ASC diagnostics or a crash service is exporting data. `MetricKit` can provide device diagnostics, but it is not itself a real-time email service and needs an ingestion path.

### Watchdog checks to implement later

The requested future MacBook script should be dry-run by default and configurable through an untracked environment file or keychain values. It should not be added in this audit because the current scope permits only `audit823.md`.

#### Release and crash signals

- New build detected in ASC or TestFlight.
- Crash-free users and crash-free sessions by app version, build, OS, device, and storefront.
- Fatal crash count and rate compared with the last stable build.
- New crash signatures first seen after the build became available.
- Launch failures, watchdog terminations, hang rate, memory termination, and app-not-responding signals if the selected data source exposes them.
- Regression threshold: alert on an absolute drop such as 0.5 percentage points or a configurable multiple of the stable baseline, with a minimum user/session count to avoid noise.
- Escalate when a new build has no diagnostics data after the expected ingestion delay, rather than interpreting missing data as health.

#### Purchase and trial signals

- Offerings load failure or empty offering.
- Product fetch failure or unknown package classification.
- Intro eligibility remains `unknown` above a threshold.
- Trial CTA impressions without trial starts.
- Purchase errors, pending purchases, cancellations, restore failures, and entitlement mismatches.
- Pro entitlement active but product configuration does not match the expected package catalog.
- Trial starts and first charge conversion by paywall surface and build.

#### Content and backend signals

- No fresh row for each expected persona and refresh window.
- `expires_at` is in the past for the current online window.
- Generation run stuck in `running` beyond a configured duration.
- Generation failures after all retries.
- RSS feed failure count or duration spike.
- Source count below the minimum or duplicate source URLs.
- Supabase 4xx/5xx and latency spikes.
- Card-art failure rate, retry exhaustion, or a spike in blank fallback art.
- App load failures split between online, cached, stale, decode, timeout, and unauthorized.

#### Acquisition and public-site signals

- App Store link, canonical URL, support, privacy, terms, and JSON-LD image all return 2xx.
- No duplicate screenshot hashes in the public asset set.
- Website claims match the product facts source.
- Sitemap `lastmod` is not older than the page content by a configured threshold.
- ASC metadata validator covers every enabled locale and no keyword file exceeds its limit.

#### Operator output

Every alert should include app name, app ID, build, observed window, metric, current value, baseline, threshold, source URL or file, and a direct next action. Email should be scaffolded but disabled until credentials and recipient are configured. A daily digest is appropriate for stale docs and low-severity consistency issues. Crash spikes, failed generation, empty offerings, and broken App Store links should be immediate.

### Release regression runbook

1. Record the last stable build and its 1-hour, 6-hour, 24-hour, and 72-hour baselines.
2. At each interval after release, compare crash-free sessions, launch failure, content load success, paywall load success, trial starts, purchase errors, and support volume.
3. Segment by iOS version, device family, storefront, app version, and traffic source.
4. If a threshold trips, stop acquisition promotion, identify the first new crash or failed path, and decide whether to pause release, ship a fix, or reduce exposure.
5. Keep an incident record with the build, first seen time, last known good build, affected path, and validation result.

## Cursor, Claude, Codex, and agent documentation hygiene

### Current structure

- Root `CLAUDE.md` is short and identifies the XcodeGen project, scheme, and simulator lease owner.
- Root `AGENTS.md` is a symlink to `CLAUDE.md`, confirmed as `./AGENTS.md -> CLAUDE.md`. This is the right canonical pattern for the local agent conventions.
- No `.cursor`, `.codex`, `.claude`, or `.agents` directory was found in the repository.
- `README.md:1-16` still starts with “The Sideline” and describes the old product name.
- `CLAUDE.md` still calls the app “Sideline” without explicitly stating that the store name is Gist. The scheme and simulator owner are correct.
- `docs/app-store-metadata.md` describes “The Gist: Sports Small Talk”, old copy, Local Team, and an old keyword strategy.
- `docs/astro-aso-setup.md` and `docs/localization-aso.md` reference an old 1.0 `PREPARE_FOR_SUBMISSION` state.
- `docs/app-store-review-strategy.md` has an old The Sideline heading.
- `scripts/aso-locale-content.json` and `scripts/astro-keywords-us.json` contain old brand and product terminology.
- `claude-design-handoff/` contains snapshots of source and design files. Several current source files, including `PaywallView.swift`, differ from the handoff copies. The handoff README should not be treated as current implementation source.
- `archive/README.md` correctly identifies archived notes as historical, but many stale files remain in active-looking root or `docs` locations.
- `RevenueCatEntitlementStore.swift` is marked deprecated and aliases the current store service.

### Agent confusion risks

1. An agent following the README can write The Sideline copy into a current Gist surface.
2. An ASO agent following `aso-locale-content.json` can overwrite current metadata with old descriptions.
3. An agent following `docs/app-store-metadata.md` can advertise Local Team even though the native app does not provide it.
4. An agent following `claude-design-handoff/source/PaywallView.swift` can make changes against a stale paywall snapshot.
5. An agent can treat `.asc-state.json` as current even though its live version is stale.
6. The code's `Sideline` identifiers are legitimate internal names, but the lack of a mapping invites accidental user-facing reversion.

### Recommended documentation layout

Do not make this audit's recommendations by editing other files in this task. For the implementation agent, the desired future state is:

- Keep `CLAUDE.md` as the canonical short agent entry point and keep `AGENTS.md` as its symlink.
- Add a small “Current product facts” section to the canonical entry point or a clearly linked current-state file: user-facing name Gist, internal project Sideline, bundle ID, ASC app ID, current release, source-of-truth locations, and known deferred features.
- Mark `docs/app-store-metadata.md`, `docs/astro-aso-setup.md`, `docs/localization-aso.md`, old review strategy notes, and design handoffs as historical or move them under `docs/archive`.
- Retire or regenerate `scripts/aso-locale-content.json`, `scripts/aso-locale-optimization-report.json`, `scripts/astro-keywords-us.json`, and `.asc-state.json` before an agent uses them for upload work.
- Put active operational runbooks in one clearly named directory and link only those from `CLAUDE.md`.
- Add a source-of-truth status marker to every strategy or handoff document: `current`, `draft`, `historical`, or `generated artifact`.
- Keep a short release checklist covering configuration, ASC version/build, RC offering, website URLs, metadata validation, content freshness, and simulator safety.

Validation: a new agent should be able to answer the product name, bundle ID, ASC ID, current version, current persona count, trial entry points, and source-of-truth files by reading only the root agent guide and its direct links.

## Prioritized implementation backlog

### P0, before more acquisition or a material release

1. Decide and resolve Local Team versus four-context product truth across native code, backend schedule, website, ASC, paywall, terms, and docs.
2. Add a Release configuration gate so sample content and local entitlements cannot silently ship.
3. Expand ASC metadata validation to all 50 locales and prevent the stale ASO generator from overwriting current listings.
4. Repair the public JSON-LD screenshot URL and replace the duplicate screenshot asset.

### P1, next conversion and reliability cycle

5. Pull and document the live RevenueCat offering, package IDs, prices, trial eligibility behavior, entitlement ID, and experiments for project `56682a14`.
6. Add paywall surface, eligibility, plan, purchase, restore, first-value, and trial funnel events.
7. Test post-first-value trial exposure and direct versus preview-first locked-room paywall routing.
8. Add a canonical product facts source and consistency scanner for app, ASC, website, terms, support, and paywall claims.
9. Enforce cache freshness and add typed load failures, request timeouts, and content health checks.
10. Add generation, RSS, Supabase, and card-art watchdog signals, with a dry-run email scaffold outside this audit file.
11. Verify the entitlement fallback and unknown package behavior in a controlled RC environment.
12. Decide whether 50 localized listings are supported, experimentally enabled, or too broad for an English-only UI.

### P2, quality and maintenance

13. Make paywall billing disclosure dynamic-height and fully accessible.
14. Surface Manage Subscription and restore errors with recovery actions.
15. Fix support page and sitemap freshness dates.
16. Add screenshot semantic manifests and public URL checks.
17. Mark or archive stale agent docs and design handoffs.
18. Replace the deprecated RevenueCat typealias after dependent references are confirmed absent.
19. Add card-art latency and fallback metrics.
20. Add a user-visible explanation for lifetime ownership and the absence of subscription management for lifetime purchasers.

## Validation plan for the implementation agent

### Static repository checks

Run from `/Users/jackwallner/sports`:

```sh
python3 scripts/validate-asc-metadata.py
```

The existing command is not sufficient until it is expanded beyond en-US. The replacement check should:

- Enumerate every locale directory under `fastlane/metadata`.
- Validate all ASC character limits with Unicode-aware counts.
- Reject old brand strings and unsupported features.
- Check all metadata URLs and release notes.
- Check duplicate keywords and blank fields intentionally.
- Compare product facts in metadata with the website and paywall source.
- Report the exact locale and field for every failure.

Also run a read-only consistency scan for:

- `Gist` versus `The Sideline` versus `Casual Sports News`.
- `4` versus `5` contexts or rooms.
- `3` versus `4` daily briefings or refreshes.
- lifetime, monthly, annual, and trial claims.
- app ID `6770138156`, bundle `com.jackwallner.sports`, version `1.1.2`, and build `53`.
- website, privacy, terms, support, metadata, paywall, and design handoff URLs.

### ASC checks

Pull, do not assume:

1. Current app status, live version, editable version, build, and release state.
2. All enabled localizations, name, subtitle, keywords, promotional text, description, release notes, support, marketing, and privacy URLs.
3. Screenshot sets and product page configuration by storefront.
4. Ratings and reviews by storefront and app version.
5. Downloads, product page views, conversion, retention, and acquisition source where available.
6. Crash, hang, launch failure, and diagnostic data segmented by build.

Record the pull timestamp and use that as the baseline for any conversion or crash conclusion.

### RevenueCat and StoreKit checks

For project `56682a14`, record:

- production entitlement ID and active offerings;
- offering ID used by the app;
- package IDs and product IDs for monthly, annual, lifetime, and any other package;
- localized prices and periods in the target storefronts;
- introductory offer duration and eligibility behavior;
- active paywall experiments and arm assignment;
- active trial, conversion, cancellation, expiration, refund, and restore metrics;
- whether the app's current hardcoded entitlement and package classifier match the dashboard.

Use StoreKit sandbox test accounts for:

- eligible first-time trial;
- ineligible account;
- monthly, annual, lifetime, and missing package cases;
- pending, cancelled, failed, and restored purchases;
- expired subscription and lifetime entitlement;
- offline paywall load and RevenueCat unavailable;
- multiple active entitlements with one unrelated entitlement.

Never use the production `appl_` key on a simulator. The existing app guard is valuable and must remain intact.

### Runtime and UX checks

Use the project's headless simulator convention, lease a device with `agent-sim checkout sports`, target the returned UDID, and release it with `agent-sim checkin sports`. Do not use a named destination or open Simulator.app.

Exercise:

1. Fresh install, onboarding, persona selection, first briefing, deck completion, source link, question card, and relaunch.
2. Locked persona from the rail, locked persona from the rooms card, and refresh-limit entry.
3. Trial eligible and trial ineligible paywall states.
4. Monthly, annual, and lifetime selection, purchase, cancellation, pending, restore, and error recovery.
5. Offline first launch, offline cached launch, expired cache, timeout, invalid JSON, empty briefing, and server error.
6. Missing release configuration, demo mode, `-SidelineEdgeCases`, and `-SidelineForcePro`.
7. Paywall snapshot modes `trial`, `monthly`, `yearly`, and `lifetime`.
8. Large Dynamic Type, VoiceOver, Reduce Motion, dark mode, rotation behavior, and accessibility labels.
9. Positive review moments, cooldown, negative feedback, direct review link, and Settings rating entry.
10. Card-art success, timeout, 402, 429, duplicate image, and fallback gradient.

### Backend and website checks

1. Confirm all expected national briefing rows exist for every scheduled window and persona.
2. Check latest generation run, failure reason, duration, source count, expiry, and art status.
3. Check RSS failures, stale feeds, and no-source generation behavior.
4. Verify the client and Edge Function return the same latest result for every supported scope.
5. Fetch every public HTML URL and asset, including JSON-LD images, sitemap pages, App Store link, canonical URL, privacy, terms, and support.
6. Compare screenshot hashes and labels.
7. Compare website plan and context claims with the canonical facts source and the live RC configuration.

## Decision points for Jack

These are the only product decisions that should be made before implementation starts:

1. Is Local Team a release promise now, or should it be removed from the acquisition surface until native support is complete?
2. Is the intended Pro freshness promise three refreshes per day, four briefing windows including the free daily briefing, or another definition? Use one phrase everywhere.
3. Is lifetime an active storefront offer that should be named in the App Store description and paywall spec?
4. Should the first trial opportunity appear after first value, only after a locked-room interaction, or both with different messaging?
5. Are the 50 localized listings an intentional English-only acquisition experiment, or should localization and screenshots be narrowed or expanded?
6. Which system will be the source of truth for funnel events and crash alerts, ASC alone, RevenueCat plus a first-party event sink, or a dedicated crash service?

## Bottom line

Gist's strongest conversion asset is the short, concrete first-value promise. The immediate work is to make every surface tell the same truth, guarantee that a release reaches real content and real purchase services, and measure the path from first briefing to trial and Pro value. Once those gates are in place, the onboarding timing, preview friction, plan framing, trial copy, screenshot set, and review timing are all good candidates for controlled experiments rather than guesswork.
