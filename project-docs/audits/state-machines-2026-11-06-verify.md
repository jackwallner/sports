VERDICT: PASS

# Verify: state machine fixes 2026-11-06

Independent check of `state-machines-2026-11-06-fixes.md` against `git diff 3cf5a42..97533211` (commits `d82126a9`, `73a9eb4d`, `cd529f27`, plus the fixes doc in `e3568fe8`). The fixes doc cites `4651ab4`, `02cbaa5` and `e5e1d5f` from the fix branch; those commits exist here and their trees match `d82126a9` and `cd529f27` exactly (`git diff` empty), so the cited ids are the same change. No verify doc existed before. The fixes doc has no "Disputed" section, so there is nothing to rule on there.

## Fixes

| Id | Works | Regression check | Evidence |
|---|---|---|---|
| 1 Offline cached briefing shows no age | Yes | No regression found | Route: cold launch or a tap on the selected chip with no signal, cache present. `load()` lands in the catch and sets `.populated(cached, savedBecause: .offline)` (`Shared/Services/TodayBriefingViewModel.swift:90`). `TodayBriefingView.deckArea` passes `savedBecause` to the banner and to `FreshnessFooter` (`Sideline/Views/TodayBriefingView.swift:327-328,345`). The footer renders straight from `BriefingFreshness` (`Sideline/Views/Components/FreshnessFooter.swift:35-50`), whose `text(now:)` has no saved-copy branch, so the age and, past 24 h, "Double-check before quoting." with the warning icon and amber tint now show (`Shared/Models/Briefing.swift:99-115`). The banner keeps the reason, so the duplicated sentence is gone. Test `testOldSavedCopyShowsItsAgeAndTheStaleWarning` drives the real load route and asserts the exact strings and icon the footer draws; it failed with the pre-fix footer logic restored (4 assertions, lines 469-473). |
| 2 Any fetch error with a cache is labelled "Offline" | Yes | No regression found | `SavedCopyReason(error:)` (`Shared/Models/Briefing.swift:56-64`) maps `BriefingServiceError.network` and bare `URLError` to `.offline`, everything else to `.serverUnavailable`. `SupabaseBriefingService` wraps every `URLSession` throw in `.network` and throws `invalidResponse`, `emptyResult` or a raw `DecodingError` otherwise (`Shared/Services/BriefingService.swift:61-83`), so a 5xx, empty answer or bad body reads "Couldn't refresh. Showing your last saved briefing." with a non-wifi icon, and the footer icon is `clock`, not `wifi.slash`. Foreground retry treats both saved states as it treated offline (`TodayBriefingViewModel.swift:111`), unchanged behaviour since every error used to be `isOffline`. `testServerErrorIsNotLabelledOffline` failed with every error mapped to `.offline`; the control `testNoConnectionShowsTheSavedCopyAsOffline` passed in the same run. |
| 5 Offline fallback leaves the positive-moment flag set | Yes | No regression found | The flag is now cleared at the top of the catch, before the cache branch (`TodayBriefingViewModel.swift:86`), so the review's route (offline chip tap, then locked tap, `roomAwaitingUnlock`, purchase, `entitlementDidChange(storedPersona: .cocktailParty)`, the value `TodayBriefingView.swift:259-262` passes) reaches `open()` with the flag false. `testOfflineChipTapThenPurchaseCountsNoPositiveMoment` makes exactly those calls and asserts both `hasPendingPositiveMoment` and the count; it failed with the clear moved back to the no-cache path (lines 525-526, count 1 vs 0). The only flag writers are `select` (sets), `refresh` (sets/clears), the catch, and `notifyPositiveMomentIfRequested`; clearing on every failure only removes moments for loads that showed a saved copy, which never counted anyway (`:228`). |
| PC5 Static "Next refresh" hint | Yes | No regression found | `RefreshSchedule.nextRefresh` picks the next 14:30, 19:30 or 23:30 UTC (`Shared/Models/Briefing.swift:19-27`), matching the cron slots 14:05 to 14:22 (and 19, 23) in `supabase/migrations/20261013000000_pg_cron_pipeline.sql:41-48`, and formats it in `TimeZone.current` each minute through the footer's `TimelineView`. The hint now hides for a saved copy or a row past 24 h (`:120-122`). Gate stays `isPro` only (`FreshnessFooter.swift:41`). Screenshot confirms it renders: "Next refresh around 2:30 PM" on a runner at about 07:45 UTC. `testNextRefreshHintOnlyForAFreshLiveRow` failed with the stale check removed (line 612). Zone tests use fixed dates and pin `en_US`; I checked the expected values by hand (London GMT, Sydney AEDT +11, Los Angeles PST after 1 Nov 2026). |
| 3 Rating ask while not active | Held for Jack | Untouched | No change to `scheduleReviewRequestAfterPositiveMoment` (`TodayBriefingView.swift:446-462`). Held is allowed for a claim the review left UNVERIFIED; the reason (no headless seam, every debug service is `isDemo`) is accurate. |
| 4 Pro preview not dismissed when Pro arrives | Held for Jack | Untouched | No change to the sheet, `ProPreviewSheet` or `PaywallView`. Held is correct here: the remaining fix would change when a paywall shows to a member, which needs Jack. |

## Regression sweep

- Every reader of `LoadState.populated`: `TodayBriefingView.swift:137` (rundown, ignores the reason), `:311` (deck area), `:360` (caught-up area, passes `nil` as before), `:438` (`isBriefingClear`, ignores the reason); view model `:111`, `:126`, `:130`, `:185`, `:228`. All carry the old semantics with `savedBecause == nil` in place of `isOffline == false`. No other target, UI test or Swift source in the build reads `isOffline` or `nextUpdateHint` (the remaining hits are the uncompiled `claude-design-handoff/` copy and the audit repro file).
- Stored data: no change to `BriefingCache`, the `Briefing` Codable shape, `RefreshWindow` cases or any UserDefaults key. `LoadState` is in memory. Upgrading users keep their cache.
- Entitlements and trials: no change to `canUse`, `isPro`, `StoreService`, paywall copy, onboarding or when a paywall shows. The hint keeps its `isPro` gate.
- Widgets, watch, notifications, undo/edit: none exist in this app.
- Day and zone changes: the hint recomputes from `TimeZone.current` on each 60 s tick; "tomorrow" is judged in the user's zone; UTC slot math is DST-free.
- Localized text: the app ships English only (no string catalogs or `.lproj`); the time follows the user's locale (24 h locales get "19:30").
- iPhone Duo: the footer and banner sit in the leading pane unchanged in structure; the new banner sentence is 8 characters longer and the label already wraps. The rundown reads `shownBriefing`, untouched.

## Scope

All six in-scope claims are in the fixes table: four fixed, two held. Nothing skipped. No change beyond the listed bugs, no backend, App Store Connect or RevenueCat change, no stored setting cleared (the positive-moment flag is in memory), no held item changed. Product call 5 was reclassified by the review as a confirmed customer-visible bug, so fixing it is in scope. Nothing must change.

## Test results

All on GitHub's Macs, Xcode 27.1, iPhone 17, iOS 27.2.

- Full suite on HEAD plus screenshots: `gh-sim all --scheme Sideline`, run `sports@20261106-231138-bf4c-claude-mbpro36816-1106-231221-10838` (GitHub run 42350289637). `Passed, 70 passed, 0 failed, 0 skipped`, matching the fixes doc. All 13 added and all 5 edited tests in `TodayBriefingViewModelTests` passed by name.
- Fail-without-fix, on a throwaway `scratch-revert` branch with the pre-fix behaviour restored behind the new API (a raw revert would not compile the new tests): run `sports@20261106-231138-bf4c-claude-mbpro36816-1107-002752-14384` (GitHub run 42355594841). `Failed, 1 passed, 4 failed`: `testOldSavedCopyShowsItsAgeAndTheStaleWarning`, `testServerErrorIsNotLabelledOffline`, `testOfflineChipTapThenPurchaseCountsNoPositiveMoment`, `testNextRefreshHintOnlyForAFreshLiveRow` failed; the control `testNoConnectionShowsTheSavedCopyAsOffline` passed. The branch was deleted.
- An earlier attempt of that proof run, `sports@20261106-231138-bf4c-claude-mbpro36816-1106-235433-15504` (GitHub run 42353214122), failed to build from my own mutation syntax and proves nothing; it was rerun as above.

## Screens

`launch.png` (`-SidelineScreenshotDemo -SidelineForcePro`) and `screen1-SidelineEdgeCases.png` show the Pro footer "Updated ... · N sources" with the new "Next refresh around 2:30 PM" line, centered, no clipping. The saved-copy banner and the saved-copy footer could not be reached: every debug briefing service succeeds and gh-sim carries no Supabase config, so no launch produces a failed fetch with a cache.

## Device checks still open

- Saved-copy banner and footer on screen, both reasons (airplane mode, and a server error), including a copy older than 24 h. The tests prove the strings and icons the footer draws, not their layout.
- Pro hint in a non-US zone and a 24 h locale.
- Bug 3 and bug 4 device checks as listed in the fixes doc's Held section.

## Notes

- "Updated in 0 seconds" on the demo briefing comes from the unchanged `relativeDate` clamp when `generatedAt` equals now; pre-existing, not from this change.
- The hint still promises a time for a live row between one missed run and the 24 h mark. Minor, the review only asked to stop it beside the stale warning.
- Pre-existing and untouched: a load superseded by a newer generation returns before the catch clears the flag (`TodayBriefingViewModel.swift:83`), so a free-room tap whose load is still in flight when a purchase opens another room could still count a moment. Not reachable in practice (the purchase would have to finish inside one fetch) and outside this change.
- The Android port keeps the static hint (`android/.../model/Models.kt`), out of scope as the fixes doc says.
