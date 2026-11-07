# Fixes: state machine audit 2026-11-06

Fixes for the claims `state-machines-2026-11-06-review.md` kept, applied on branch `fleet/20261106-212041-a9b8-claude` from `3cf5a42`. No earlier fix run or verify file existed.

**Summary: 6 claims in scope. 4 fixed (in 3 commits), 2 held for Jack, 0 skipped.**

## Claims

In the review's ranked order, then the unverified claims in the order it gave to settle them.

| Id | Review verdict | Result | Commit | Regression test (`SidelineTests/TodayBriefingViewModelTests`) | What changed |
|---|---|---|---|---|---|
| 1 Offline cached briefing shows no age | CONFIRMED | Fixed | `4651ab4` | `testOldSavedCopyShowsItsAgeAndTheStaleWarning`, `testRecentSavedCopyShowsItsAge` | The footer no longer returns the offline sentence before the age rule. A saved copy reads "Updated N ago · S sources", or past 24 h "Updated N ago. Double-check before quoting." in amber with the warning icon, exactly like a live row. The banner above the deck still says why the copy is saved, so the duplicated sentence is gone. The footer's text rules moved into `BriefingFreshness` (`Shared/Models/Briefing.swift`) so a unit test can read them. |
| 2 Any fetch error with a cache is labelled "Offline" | CONFIRMED | Fixed (same commit as 1, shared cause) | `4651ab4` | `testServerErrorIsNotLabelledOffline`, `testEmptyResultIsNotLabelledOffline`, `testUndecodableBodyIsNotLabelledOffline`, `testServerUnavailableBannerDoesNotSayOffline`, control `testNoConnectionShowsTheSavedCopyAsOffline` | `LoadState.populated` carries `savedBecause: SavedCopyReason?` instead of `isOffline: Bool`. A transport failure (`BriefingServiceError.network`, `URLError`) is `.offline`; a 5xx, an empty result or an undecodable body is `.serverUnavailable`, shown as "Couldn't refresh. Showing your last saved briefing." Foreground retry treats both saved states the way it treated offline. |
| 5 Offline fallback leaves the positive-moment flag set | CONFIRMED | Fixed | `02cbaa5` | `testOfflineChipTapThenPurchaseCountsNoPositiveMoment` (the review's real route through `roomAwaitingUnlock`, not SM1's `storedPersona: .dateNight`), `testOfflineChipTapLeavesNoMomentForALaterLapse` (survives a foreground reload, fires on a lapse), control `testLiveChipTapCountsAPositiveMoment` | `load()` clears `shouldRecordPositiveMomentOnNextSuccess` on every failure, including the saved-copy branch, so it never reaches a later load opened by a paywall or a lapse. |
| Product call 5 Static "Next refresh" hint | CONFIRMED (review: a customer-visible bug) | Fixed | `e5e1d5f` | `testNextRefreshIsTheNextRunInUTC`, `testHintReadsTheNextRunInTheUsersZone`, `testNextRefreshHintOnlyForAFreshLiveRow` | `RefreshWindow.nextUpdateHint` (fixed per window) is replaced by `RefreshSchedule`: the next of the 14:30, 19:30 and 23:30 UTC landings after now (cron starts 14:05, 19:05, 23:05; the last room starts at :22), read in the user's zone: "Next refresh around 7:30 PM" or "Next refresh tomorrow around 1:30 AM". The hint is hidden once the row is past the 24 h stale mark, so an outage no longer shows a confident time beside "Double-check before quoting". |
| 3 Rating ask spent while the app is not active | UNVERIFIED | Held | | | See Held for Jack. |
| 4 Pro-offering sheet not dismissed when Pro arrives | UNVERIFIED (audit route refuted) | Held | | | See Held for Jack. |

Not touched: product calls 1, 2, 3, 4 and 6 (the review agreed they are product calls), and the Android port's copy of the static hint (`android/.../model/Models.kt`), which is outside this iOS fix run.

## Held for Jack

- **Bug 3, rating ask while backgrounded.** No headless test can settle it: every debug briefing service sets `isDemo` and the ask returns on `isDemo` (`TodayBriefingView.swift:447`), gh-sim cannot carry the Supabase config, and the open question is iOS behaviour (whether the sleeping task resumes in the background, and whether the system drops a `requestReview()` made then), which a simulator debug build, where the prompt always shows, would not answer. Decision: run the review's device check (2nd launch, switch room, Home within 1 s, return after 10 s, log scene phase and `lastShownDate` at `markShown`), or accept the one-line guard (`scenePhase == .active` after the 3.5 s sleep, before `markShown()`) without proof.
- **Bug 4, Pro preview left open when Pro arrives.** The audit's route is refuted (RevenueCat delivers cached CustomerInfo when the delegate is set). The remaining route, a delegate push (Ask to Buy approval, Family Sharing refresh) while a Pro preview is up, needs the entitlement granted mid-sheet: the Test Store probe can only buy from the paywall, which dismisses itself, and a server-side grant needs RevenueCat's secret key, which must not go to gh-sim. It also touches when a paywall appears to a member. Decision: approve a StoreKit-configuration Ask to Buy UI test (or a local Test Store grant run on the Air), or approve closing `.proPreview` and `.paywall` sheets on `isPro` becoming true without that proof.

## Skipped

None.

## Test results

Both runs used Xcode 27.1, iPhone 17 and iOS 27.2 on GitHub's Macs.

- **Full suite, final branch state** (`e5e1d5f` plus this doc): `gh-sim test --scheme Sideline`, run id `sports@20261106-212041-a9b8-claude-mbpro33c0e-1106-213854-10074` (GitHub run 42343618755). Result: `Passed, 70 passed, 0 failed, 0 skipped`, all 13 new tests included. No test failed, so none needed checking against `3cf5a42`, and none was already failing there as far as this suite shows.
- **Proof the regression tests catch the bugs**: the same 11 new view model tests run on a working tree where the pre-fix behaviour sat behind the new API (every error mapped to `.offline`, the footer returning the offline sentence for any saved copy, the moment flag cleared only on the no-cache path, the static "Next refresh midday" hint, and the hint not hidden when stale). Run id `sports@20261106-212041-a9b8-claude-mbpro33c0e-1106-223828-27170` (GitHub run 42347912674). Result: `Failed, 2 passed, 9 failed`. All 9 regression tests failed; the 2 controls (`testNoConnectionShowsTheSavedCopyAsOffline`, `testLiveChipTapCountsAPositiveMoment`) passed. The mutation was never committed. On `3cf5a42` itself, the review's run `sports@20261106-201612-f59a-claude-mbpro3739e-1106-202408-21457` already showed the bug 2 and bug 5 routes failing (`testSM1`, `testSM2`, `testR2_*`, `testR5_*`).
- `testNextRefreshIsTheNextRunInUTC` checks the new schedule math and has no pre-fix counterpart, so it was left out of the proof run.
- The audit's repro suite and the review's checks were never added to the test target. The regression tests reuse their routes (the review's `testR5_*` route for bug 5, its `testR2_*` cases for bug 2), not the files.
