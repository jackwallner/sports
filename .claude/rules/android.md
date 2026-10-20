---
paths: ["android/**"]
---

# Gist on Android

Native Kotlin/Compose port of the iOS app in `android/`. The iOS app is the
spec: same copy, rooms, deck, paywall and paid boundary. Shared Android
conventions live in the `android-dev` skill.

## Identity
- Package and namespace `com.jackwallner.sports` (permanent once uploaded).
  Play listing name `Gist: Sports Small Talk`; launcher label `Gist`; in-app
  title `Sports Cheat Sheet` (iOS `SidelineBrand.name`).
- `versionName` tracks iOS `MARKETING_VERSION` (1.1.4); `versionCode` starts at
  1 and goes up on every upload.
- RevenueCat entitlement `Sports Pro` (`Membership.ENTITLEMENT_ID`, same as
  iOS); the paywall reads the `default` offering, then current, then the first
  non-empty one. Play product IDs must equal the iOS product IDs; subscriptions
  get one base plan per period (`monthly`, `yearly`) with the 7-day trial as a
  new-customer offer on both (monthly trials stay), plus the lifetime in-app
  product. Read the live iOS prices and PPP ladder from ASC on the Air before
  creating them: `fastlane/metadata/en-US/description.txt` still says
  $5.99/$29.99, while the 2026-06-29 pricing pass cut subscriptions to
  $2.99/$19.99. The RevenueCat Test Store shows its own sample prices
  ($9.99, $79.99, $99.99); they are not the Play prices.

## Build and test (jmbp or jmbp2, never the Air)
- `JAVA_HOME=~/jdks/temurin-17/Contents/Home` (the bundle root is not a JDK
  home). On jmbp2 (8 GB, dual-core i5) pass
  `--no-daemon -Dorg.gradle.jvmargs=-Xmx2g --max-workers=2`.
- `./gradlew testDebugUnitTest assembleDebug lintDebug`, then
  `ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest`.
- jmbp2 AVD: `agent-emu-1` (API 36 Google Play, x86_64, no Play account).
  Boot: `emulator -avd agent-emu-1 -port 5554 -no-window -no-audio
  -no-boot-anim -no-metrics -no-snapshot-save`, wait for
  `adb -s emulator-5554 shell getprop sys.boot_completed` = 1. Stop:
  `adb -s emulator-5554 emu kill`, then confirm the serial is gone. It is slow
  enough that System UI can ANR right after boot; tests use 30-45 s waits.
- Unit tests: `IosParityTests.kt` ports all 34 iOS tests one for one;
  `AndroidPortTests.kt` checks CardArt against `cardart-parity.json`
  (written by Swift itself via `scripts/sync-android-fixtures.sh`; rerun it
  after changing `CardArt.swift` or `Shared/Models`), the deck boundary,
  paywall copy and the reviewer code.
- Connected tests (`GistFlowTests`) cover first run, locked rooms, the Test
  Store paywall, Pro, the deck to the rooms card, TalkBack deck actions, the
  reviewer code and the live Supabase feed.

## Keys and boundaries
- `android/local.properties` (ignored) holds `REVENUECAT_TEST_KEY` (debug, Test
  Store), `REVENUECAT_PLAY_KEY` (release only), `SIDELINE_SUPABASE_URL` and
  `SIDELINE_SUPABASE_ANON_KEY` (same public values as iOS), and
  `PLAY_REVIEW_CODE_SHA256` plus the upload keystore entries. The upload key
  and production Play key stay on the Air; release tasks fail without them
  (`validateReleaseConfiguration`).
- `StoreService.configureIfNeeded` refuses a `goog_` key in debug and a non-Play
  key in release. The `qa` build type is release code with no RevenueCat key.
- Debug launch extras (`DebugLaunchOptions.kt`, debug source set only):
  `uiTest`, `onboarded`, `demo`, `safeScreenshot`, `edgeCases`, `forcePro`,
  `persona`, `deckStart`, `appearance`. Release ignores all of them.
- Play reviewer access: long-press the Settings Version row, enter the code
  from the review notes. Only its SHA-256 ships. The plain code lives with
  Jack, not in the repo.

## Intentional differences from iOS
- No enjoyment gate (none on iOS either now). The Play review card is called
  directly after a positive moment with the same tracker cooldowns; Settings
  has separate Send Feedback and Rate Gist rows. Rate opens the Play listing.
- Paywall disclosure names Google Play renewal and cancellation instead of
  Apple's 24-hour wording; Manage Subscription deep links to Play.
- Source links open in a Custom Tab; returning to the app retries a blocked
  review ask, like the iOS Safari sheet's dismissal.

## Play Console state (2026-10-20)
- Not live on Play (absent from the fleet's 16 live packages on 2026-10-20).
  No upload, Play products or RevenueCat Play app are recorded; confirm the
  Console app record from the Air before creating one. Listing copy is in `android/play-assets/listing/`; release prep and the
  remaining Console steps are in
  `project-docs/android/play-release-prep.md`.
