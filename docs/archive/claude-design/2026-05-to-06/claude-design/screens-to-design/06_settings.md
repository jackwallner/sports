# 06 — Settings

**Target:** `Sideline/Views/SettingsView.swift`
**Priority:** P1 — small surface, but it holds the Local Team Pro lever and the App Store-required restore/links.
**Status:** Does not exist. Greenfield.

## Job
A short, stock-feeling settings screen that (a) sells Local Team personalization, (b) satisfies App Store requirements (restore, privacy), (c) lets a Pro user manage their subscription, (d) offers a manual refresh — gated by tier.

## Sections (a `Form` is fine here — don't over-design it)
1. **The Sideline Pro** — if free: a row/card that opens the paywall (`09`), naming the three benefits (all contexts, fresh 3×/day, local team). If Pro: "Pro · active" + a "Manage subscription" link (App Store subscriptions URL).
2. **Local team** — city/team picker. **Pro-gated:** free users see the row with the consistent lock affordance (matches `04`/`08`); tapping routes to paywall. Pro users edit it inline. Stored in `GoalSettings.favoriteCity/favoriteTeam`.
3. **Briefing** — "Refresh now" (respects tier: free = once/day, shows the limit state from `10` when used; Pro = always). Optionally a default-persona picker.
4. **About** — Privacy Policy link, Terms link, app version. Restore Purchases lives here too (and/or on the paywall).
5. **Debug** (DEBUG builds only) — a toggle calling `SubscriptionService.setLocalOverride(isPro:)` so QA can flip Pro. Hidden in release.

## What we don't want
- Account/sign-out (accountless app — never).
- A second lock vocabulary — reuse `04`'s.
- Notification settings (the app doesn't push in v1).
- A bespoke settings UI; `Form` + `Section` is correct and expected here.

## Constraints
- iOS 17 SwiftUI `Form`, dark mode, AX5.
- Restore Purchases + Privacy/Terms must be present and reachable (App Store review requirement).
- "Manage subscription" opens the system subscriptions sheet/URL — not a custom screen.

## Questions your mockup must answer
1. Is Pro a top card (prominent) or a quiet first row? Free vs Pro layouts likely differ — show both.
2. Local-team picker UX for Pro: free-text city, a curated team list, or both? Recommend the lowest-friction one that still maps to a backend "scope" slug.
3. Where does Restore live — Settings, paywall, or both? Justify against App Store norms.
