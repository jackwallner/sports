# State machine audit: Gist (Sideline), 2026-11-06

Scope: iOS app (`Sideline/`, `Shared/`) at commit `e5bf9ec`, plus the Supabase functions and migrations that decide what the app can read (read only). There are no widget or watch targets. Android is out of scope. Nothing was fixed.

**Summary: 5 bugs. 2 proved by failing test, 3 code path only.** 6 Product calls (not counted). No bug touches money directly: purchase, trial and entitlement code held up under the paths tried (see "Ruled out").

Evidence run: `gh-sim test --scheme Sideline --only SidelineTests/StateMachineAuditRepro`, run id `sports@20261106-191403-c376-claude-mbpro376d1-1106-192203-9010`, Xcode 27.1, iPhone 17, iOS 27.2. Result: `Failed, 4 passed, 2 failed`. Repro suite: `state-machines-2026-11-06-repro.swift` (copy into `Tests/SidelineTests/` to run).

## Test seams in this app

| Seam | Where | Used |
|---|---|---|
| `BriefingServing` fake | `TodayBriefingViewModelTests.MockService` | yes (`ScriptedService` in the repro) |
| `LocalEntitlementStore(isPro:)` + `setProForDebug` | `Shared/Services/Entitlements.swift` | yes |
| `ConversionDiagnostics.defaultsOverride` | `ConversionDiagnostics.swift` | not needed (no bug found there) |
| `ReviewPromptTracker` statics with `now:` parameters, backed by `UserDefaults.standard` | `ReviewPromptTracker.swift` | yes (read and reset) |
| `BriefingCache` (real SwiftData store, created inside the view model) | `TodayBriefingViewModel.init` | indirectly, no injection point |
| Notification scheduler | none: the app schedules no local or remote notifications (`grep UNUserNotification` finds nothing) | n/a |
| `CustomerInfo` fixtures | none in the repo; `StoreService` is a singleton with a private init and talks to `Purchases.shared` | not available |
| `NSTimeZone.default` | the only day-keyed logic (`todayStamp`) uses a UTC formatter, so a zone change cannot move it | n/a |
| Views (`TodayBriefingView`, `FreshnessFooter`, `PaywallView`) | app target; `SidelineTests` depends on `Shared` only | not reachable from unit tests |

Anything in view `@State` or the footer's rendering therefore stays "Code path".

## Bugs, ranked by users reached times cost

| # | Bug | What the user sees | Promise | User route | Impact | Evidence | file:line |
|---|---|---|---|---|---|---|---|
| 1 | Offline cached briefing shows no age and no stale warning | A briefing generated days ago under "Offline. Showing your last saved briefing." with a wifi-slash icon; no "Updated N days ago", no "Double-check before quoting" | `FreshnessFooter.swift:57,65-67`: past 24 hours the footer says "Updated X. Double-check before quoting." The cache has no age limit (`BriefingCache.load`) | Open Gist on a plane or with no signal more than a day after the last online open (Cocktail Party or any unlocked room), look at the footer under the deck | Every user who opens the app offline after a gap, and every user during a backend outage (bug 2 routes them to the same label). Cost: they quote old news as current to the people the app exists for | **Code path.** Reachability passes: `testSM3_FiveDayOldCacheIsServedAsPopulatedOffline` shows a 5-day-old row arrives as `.populated(_, isOffline: true)`. The text branch is `FreshnessFooter.swift:61-63` (`isOffline` returns before the stale check at 65). Settled by a UI test that seeds an old cache and reads the footer label | `FreshnessFooter.swift:57-67`, `TodayBriefingViewModel.swift:84-88`, `BriefingCache.swift:63-75` |
| 2 | Any fetch error with a cached row is labelled "Offline" | "Offline. Showing your last saved briefing." while the device is online and the server answered 503, 5xx or unparseable JSON | `TodayBriefingView.swift:567` and `FreshnessFooter.swift:63`: "Offline." The same view model gives a specific message when there is no cache (`BriefingServiceError.errorDescription`: "Server returned 503. Try again in a moment.") | With a cached briefing, launch or pull a room switch while the Supabase REST endpoint returns an error (outage, paused project, bad deploy) | All users with a cache during any backend failure; a one-off per incident but all at once. Cost: they toggle airplane mode or Wi-Fi chasing a fault that is not theirs, and bug 1 hides the age | **Test, fails.** `testSM2_ServerErrorIsNotLabelledOffline`: "a 503 from a reachable server was labelled Offline". Control `testSM2_Control_NoConnectionIsLabelledOffline` passes | `TodayBriefingViewModel.swift:81-89` (catch branch ignores the error type) |
| 3 | A rating ask can be spent while the app is not active | No prompt appears, and the 30-day cooldown, the session flag and the pending moment are all consumed, so the next ask is a month away | `ReviewPromptTracker.swift:33-36` (doc): the cooldown paces real asks, and `TodayBriefingView.swift:442-445` says it asks "only if the briefing is still clear". The 3.5 s wait never checks `scenePhase` | Finish a briefing (reach "Your move") or switch room, then press Home or lock the phone within 3.5 s. The sleep resumes on return, `isBriefingClear` is still true (no sheet), `markShown()` runs and `requestReview()` is called as the scene becomes active or before | Users on their 2nd or later launch who leave the app quickly after a briefing; common for a glance-and-go app. Cost: one lost rating ask per 30 days | **Code path.** `TodayBriefingView.swift:454-463`: no `scenePhase == .active` check between `Task.sleep` and `markShown()`/`requestReview()`. Settled by a UI test that backgrounds the app 1 s after the card and then checks `lastShownDate` against whether the system sheet appeared | `TodayBriefingView.swift:454-463` |
| 4 | A sheet that offers Pro is not dismissed when Pro arrives | A subscriber (including a lifetime owner) sees "Try Date Night Free" or the full plan list | `SettingsView.swift:42`: "A subscriber is never offered the plans they already own." | Cold launch of a paying user on a slow connection (or the first launch after Restore is still in flight): tap a locked room chip in the first seconds, before RevenueCat returns `isPro`. The preview opens, `isPro` flips, `entitlementDidChange` opens the room behind it (`TodayBriefingView.swift:259-262`) but `activeSheet` stays `.proPreview`. "Try Free" opens `PaywallView`, whose `onChange(of: store.isPro)` (`PaywallView.swift:46`) never fires because the value is already true | Paying users who tap a locked chip inside the first RevenueCat round trip (sub-second to a few seconds). Rare. Cost is real money for a lifetime owner who buys a subscription on top | **Code path.** No unit seam: `activeSheet` is view `@State` and `StoreService.isPro` cannot be driven without the SDK. Settled by a UI test with the RevenueCat Test Store probe (`RevenueCatProbe`) that delays the entitlement | `TodayBriefingView.swift:233-238,259-262`, `PaywallView.swift:46-48` |
| 5 | Offline fallback leaves the positive-moment flag set | A rating prompt about 3.5 s after a Pro purchase | `TodayBriefingViewModel.swift:165-166` (doc on `open`): "Switches room without counting a positive moment: this follows a paywall, which never leads into a rating ask." AGENTS.md: "a paywall or Pro preview never does" | Free user, no signal: tap the selected Cocktail Party chip (cache shows, banner says Offline). Later online: tap a locked chip, "Try ... Free", buy. `entitlementDidChange` calls `open`, `load` consumes the leaked flag, `recordPositiveMoment` posts, and the ask fires once the paywall is gone (2nd launch onward, no prior ask in 30 days) | Free users who tap a chip while offline and then convert in the same process. Small. Cost: a rating prompt at the moment of purchase | **Test, fails.** `testSM1_OfflineRoomTapThenPurchaseDoesNotCountAPositiveMoment`: "a room opened after a paywall must not count a positive moment". Control `testSM1_Control_PurchaseWithoutOfflineTapRecordsNothing` passes | `TodayBriefingViewModel.swift:139,84-89` (flag set, cache path returns without clearing), `:80,222-228` |

Fix grouping, in order:
1. Bugs 1 and 2 together: carry the failure kind (offline versus server) and the cached row's age into `LoadState.populated`, and let the footer apply the stale rule to the offline text.
2. Bug 3: gate the ask on `scenePhase == .active` after the sleep, before `markShown()`.
3. Bug 4: clear `activeSheet` for the two Pro-offering cases when `isPro` becomes true.
4. Bug 5: clear `shouldRecordPositiveMomentOnNextSuccess` in the cache branch of `load()`.

## Product calls (not counted)

No promise text, or the behaviour is a documented rule.

1. **Pro's "fresher briefings" is not gated.** Paywall copy ("Fresh stories morning, midday, and evening", `PaywallView.swift:198`; Settings "fresh 3x/day", `SettingsView.swift:216`) and `Sideline/copy/PAYWALL.md` sell freshness, but the app reads the newest row for every user (`BriefingService.swift`, `order=generated_at.desc&limit=1`) and `reloadIfStale` runs for free users too. Evidence passes: `testProductCall_FreeUserForegroundReloadSwapsInNewerRow`.
2. **The refresh-limit machine is unreachable from the UI.** Settings only calls `viewModel.refresh()` when `isPro` (`SettingsView.swift:69-75`); free users get the paywall. So `LoadState.refreshLimit`, `caughtUpBanner`, `caughtUpEmptyState`, the `sideline_refresh_limit_paywall` impression and `lastFreeRefreshDay` are dead. If revived, the day key is a UTC date (`ISO8601DateFormatter` default zone), so the budget resets at 5 pm Pacific.
3. **Paid rooms are client-gated only.** `briefings` has a public select policy (`20260516214000_initial_sideline_schema.sql:135`) and the anon key ships in the app, so anyone can read the four rooms.
4. **`sideline://room/<persona>?card=N` is registered (Info.plist) and callable by any app or web page.** If the room load fails, `pendingDeckCard` is not cleared (`TodayBriefingView.swift:378-384`) and is applied to a later, unrelated briefing. No shipping UI produces such a link, so no route.
5. **Pro-only footer hint is static.** `RefreshWindow.nextUpdateHint` ("Next refresh this evening") ignores the clock, the user's zone (windows are UTC: cron 14:05, 19:05, 23:05, `20261013000000_pg_cron_pipeline.sql`) and staleness, so a Pro user in Sydney or Berlin, or during an outage, reads a wrong time.
6. **Paywall offering choice ignores RevenueCat `current` when a `default` exists** (`StoreService.swift`, `sidelinePaywallOffering`); documented in its comment, but it would defeat any offering-based experiment or targeting.

## Ruled out (looked hard, no reachable defect)

- **Stale response overwrites:** `loadGeneration` guards `load`, `reloadIfStale`, `select`; covered by `testSlowStaleLoadDoesNotOverwriteNewerSelection`.
- **Cold launch of a Pro user:** the stored room falls back to Cocktail Party until `isPro` arrives, then `entitlementDidChange` reopens it from `lastPersonaRaw`, which is not overwritten on the way.
- **Rooms card after buying Pro:** `BriefingDeck.swift:127-129` clamps the index when the card count drops.
- **Pending (Ask to Buy):** RevenueCat's throw is mapped to `.pending` (`StoreService.swift`, `SidelinePurchaseState(purchaseError:)`), tested; approval arrives through the delegate and dismisses the paywall.
- **Trial eligibility:** fetched once per process and not refreshed after a purchase. It only matters once `isPro` goes false again in the same process (expiry or refund after days); not counted, no route short of a multi-day process.
- **Stale `CustomerInfo` landing after a newer one:** `StoreService.apply` does not compare `requestDate`. A slow launch fetch landing after a purchase would flip `isPro` back. Needs a purchase inside the first seconds on a slow link and no fixture exists to prove it, so it is a note, not a bug.
- **Notifications:** none exist. The patterns about scheduled notifications, permissions and reminder toggles do not apply.
- **User-recoverable data, undo and edit paths:** the app stores no user-authored data. Persisted state is `hasCompletedOnboarding`, `lastPersona`, `hasSwipedDeck`, `appearanceMode`, the review-tracker keys, `conv.*` counters (analytics only) and the briefing cache.
- **Side-by-side panes (iPhone Duo):** deck and rundown share one `deckIndex` binding and the deck resets `flippedPosition` on index change. A rundown tap landing inside the 0.26 s fling would advance from the new index (`BriefingDeck.swift`, `fling` completion), but that needs an unfolded Duo and a precisely timed tap, so it is not counted.

## State machines

### SM-A. Briefing load (`TodayBriefingViewModel`)

States: `idle`, `loading`, `populated(briefing, isOffline)`, `failed(message)`, `refreshLimit` (dead, see Product call 2). Side fields: `selectedPersona`, `lastBriefing`, `lastFetchedAt`, `roomAwaitingUnlock`, `loadGeneration`, `shouldRecordPositiveMomentOnNextSuccess`, `hasShownLimitThisSession`.

Invariants:
- I1. A response lands only if its generation is current.
- I2. `populated(_, isOffline: true)` means the device could not reach the server.
- I3. A cached row shown offline is marked as such and its age is visible.
- I4. `selectedPersona` is usable under the current entitlement once an entitlement change has been processed.
- I5. `shouldRecordPositiveMomentOnNextSuccess` is true only while the load that set it is the active load.
- I6. `roomAwaitingUnlock` is non-nil only while a preview or paywall for it is open.

| From | Event | To | Notes |
|---|---|---|---|
| idle | `.task` `load()` | loading | `TodayBriefingView.swift:211` |
| any | `load()` | loading | bumps generation |
| loading | fetch ok, generation current | populated(live) | saves cache, records moment if flag |
| loading | fetch fails, cache hit | populated(cached, offline) | **breaks I2** for non-network errors (bug 2), **I3** (bug 1), **I5** (bug 5: flag not cleared) |
| loading | fetch fails, no cache | failed | clears flag |
| loading | fetch result, generation stale | unchanged | I1 holds |
| populated | foreground, older than 5 min or offline | populated | `reloadIfStale`; failure keeps state; same id keeps deck |
| failed | foreground | loading | via `load` |
| any | `select(free or unlocked)` | loading | sets flag, writes `lastPersona` |
| any | `select(locked)` | unchanged | sets `roomAwaitingUnlock`, view opens preview |
| any | `entitlementDidChange`, Pro gained | loading (if target differs) | `open` does not set flag (**bug 5** leaks it) |
| any | `entitlementDidChange`, Pro lost, room paid | loading | falls back to Cocktail Party, writes `lastPersona` |
| any | `refresh()` free | refreshLimit or loading | unreachable from UI |

### SM-B. Entitlement and purchase (`StoreService`, `PaywallView`)

States: `isPro`, `customerInfo`, `products`, `introEligibility(+Checked)`, `purchaseInFlight` (written, never read), view `isPurchasing`/`isRestoring`/`selectedPackage`/messages.

Invariants: `isPro == customerInfo.hasSidelineProEntitlement` after every `apply`; a paywall closes when `isPro` turns true; a subscriber is not offered plans (`SettingsView.swift:42`); trial copy shows only for eligible packages.

| From | Event | To | Notes |
|---|---|---|---|
| free | `start()` fetch, delegate update, purchase, restore | `apply(info)` | last writer wins, no `requestDate` check (note above) |
| free, paywall open | purchase succeeds, entitlement active | Pro, paywall dismisses | `PaywallView.swift:46` |
| free | purchase throws payment pending | free, message | approval later arrives via delegate |
| free | purchase cancelled | free, silent | |
| Pro | entitlement lapses | free | view model reopens free room; **bug 4** shows the mirror case: sheets opened while free are not closed on gain |
| free | restore finds nothing | free, `lastError` | |

### SM-C. Sheets and unlock intent (`TodayBriefingView`)

`activeSheet` in `none | proPreview(p) | paywall(p, id) | source(url)`, plus `isShowingSource`, `isShowingSettings`, `pendingDeckCard`. Transitions: chip tap on locked room none to proPreview; "See Pro" proPreview to paywall in place (no dismiss callback); dismiss to none (clears `roomAwaitingUnlock` if not Pro); source dismiss retries the review ask. Invariant: no Pro-offering sheet is open while `isPro`; broken by bug 4. A URL route sets `activeSheet = nil` mid-purchase, harmless because the purchase task is not tied to the view.

### SM-D. Review ask (`ReviewPromptTracker`, `TodayBriefingView`)

Persisted: `appLaunchCount`, `lastShownDate`, `outcome`, `positiveMomentCount`, `hasPendingPositiveMoment`. States: no-ask, pending, shown (cooldown 30 days), ended (`openedWriteReview`). Invariant: `markShown` only when the system could show the prompt; broken by bug 3. Pending moment is consumed only by `markShown`.

### SM-E. Onboarding and persona persistence

`hasCompletedOnboarding` (AppStorage), `lastPersona`, `selectedPersona`. `finish()` stores Cocktail Party when the pick is locked. Completion triggers both `onChange(hasCompletedOnboarding)` and `.task` loads; the second supersedes the first (extra request, no wrong state).

### SM-F. Deck and rundown (`BriefingDeck`, `BriefingRundown`)

Shared `deckIndex`, deck-local `flippedPosition`, `isFlinging`, `drag`, `finishedBriefingID`, `deckBriefingID`. Index resets to 0 when the briefing id changes; free decks have one extra card (rooms) that disappears when Pro arrives (clamped). "Your move" index is `bullets.count + 1` and counts once per briefing.

### SM-G. Conversion diagnostics (`ConversionDiagnostics`)

Counters only, never gate behaviour. First pitch freezes earliness; first conversion freezes the sale. A purchase that finishes through Ask to Buy approval or Restore is never recorded as a conversion (`purchase()` is the only caller), which is analytics loss, not user harm.

### SM-H. Backend freshness (read only)

pg_cron at 14:05, 19:05, 23:05 UTC invokes ingest then one persona every 4 minutes; windows are the UTC hour (<16 morning, <22 midday, else evening). A failed persona keeps its previous row (the app reads the latest row of any age, so outages surface as stale rows, which is why bug 1 matters). The app never reads `expires_at`.
