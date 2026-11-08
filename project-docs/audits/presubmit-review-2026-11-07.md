# Pre-submit review: Gist 1.1.6 (2026-11-07)

Scope: app sources changed since the live version 1.1.5 (`8c548cd`, the 1.1.5
bump) to `a3138be` (main, 1.1.6 build 67). Backend (`SupabaseFunctions/`,
`supabase/`) has no changes in that range. Files reviewed:

- `Shared/Models/Briefing.swift` (new `RefreshSchedule`, `SavedCopyReason`, `BriefingFreshness`)
- `Shared/Services/TodayBriefingViewModel.swift` (`populated(_, savedBecause:)`)
- `Sideline/Views/TodayBriefingView.swift`, `Components/FreshnessFooter.swift`, `Components/BriefingDeck.swift`
- `Sideline/Views/OnboardingView.swift`, `Sideline/Utilities/CardArt.swift`

## Findings

| Severity | Location | What happens | Status |
|---|---|---|---|
| P1 | `Shared/Services/TodayBriefingViewModel.swift:187` | A free user taps refresh while offline or during a server failure. The fetch fails, the saved copy is shown as `.populated(_, savedBecause: .offline)`, and the `if case .populated` check still stamps the day's one free refresh as spent. A retry once back online hits the refresh limit instead of fetching. The check predates 1.1.6, but the same code ships in this release. | Fixed: only a fresh fetch (`savedBecause: nil`) spends the refresh. Regression test `testFailedFreeRefreshDoesNotSpendTheDaysRefresh`. |

## Checked, no defect

- `SavedCopyReason(error:)`: `BriefingService` wraps every transport error in `.network`, so a dropped connection reads Offline; HTTP errors, empty rows and decode failures read "Couldn't refresh". Covered by existing tests.
- `RefreshSchedule`: the UTC slots (14:30, 19:30, 23:30) match the pg_cron schedule in `20261013000000_pg_cron_pipeline.sql` (runs start at :05, last room at :22). No force unwraps; it falls back to +12h if the calendar returns nothing. Shown to Pro only, and only for a fresh, non-stale row.
- `reloadIfStale`: a saved copy always refetches on foreground and becomes a fresh `populated` on success; a failed refetch leaves the screen unchanged.
- Positive-moment flag: now cleared on every failed load, so a saved copy never leads into `requestReview()`.
- `BriefingDeck` Reduce Motion fling: `finishFling` resets `isFlinging`, `drag` and `flippedPosition` on both paths, so the deck cannot get stuck mid-swipe.
- `OnboardingView` Back button: on page 0 it is invisible, not hit-testable and hidden from VoiceOver. Onboarding cannot go back from page 0 or skip a page.
- `TodayBriefingView` skeleton cross-fade and `CardArtImage` fade: animation-only changes.
- Purchase, paywall, restore and `isPro` gating: no changes since 1.1.5.
- App Review strings in the diff: no prices, no other platforms, no predictions or betting language, no placeholder or debug UI. `Sideline/Debug/EdgeCaseBriefing.swift` is unchanged since 1.1.5.

## Tests

Not run. `gh-sim test --scheme Sideline --only SidelineTests` (run
`sports@20261107-225948-dc4d-claude-imacc921-1107-230643-18875`, GitHub Actions
42457435262) sat queued for 90 minutes with 0 of 5 GitHub Macs running and 24
fleet runs waiting, then was cancelled. This imac has no Xcode. Run
`SidelineTests` locally before submitting; the new test is
`TodayBriefingViewModelTests.testFailedFreeRefreshDoesNotSpendTheDaysRefresh`.
