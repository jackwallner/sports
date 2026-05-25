# App Store review prompts (The Sideline)

Implements the reusable playbook in `app-store-5-star-review-strategy.md` (Desktop).

| Constant | Value |
|----------|-------|
| App Store ID | `6770138156` |
| Write-review URL | `AppStoreReviewLinks.writeReviewURL` |
| Feedback email | `jack@jackwallner.com` |
| Positive moment | Fresh online briefing after pull-to-refresh, manual refresh, persona switch, or local-team change |
| Avoid | Cold launch, onboarding, errors, paywall / Pro preview sheets |

**Code:** `Shared/Services/ReviewPromptTracker.swift`, `Shared/Utilities/AppStoreReviewLinks.swift`, `Sideline/Views/ReviewPromptSheet.swift`, host in `TodayBriefingView.swift`.
