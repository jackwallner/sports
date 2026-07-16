# 01 — Onboarding (3 pages)

**Target:** `Sideline/Views/OnboardingView.swift`
**Priority:** P0 — first 15 seconds, and it picks the user's starting room.
**Status:** Does not exist. Greenfield.

## Job
Get a non-fan from cold-open to their first briefing in under 15 seconds, having chosen the context that actually matches their life. Convey "this makes you sound like you follow sports — without following sports" without being smug about it.

## The 3 pages
1. **Value prop.** App name + one-line promise + a single "Get started" CTA. No carousel. One screen, full takeover, no tab bar.
2. **Pick your context.** The five personas as choosable cards/rows. Free users can pick any to *look at*, but will land on Cocktail Party (the free one) — so design how a Pro persona is shown here: chosen-but-tagged-Pro, or selectable-with-a-Pro-badge that routes to paywall on continue? Recommend one and show it.
3. **Your team (optional).** "Following a local team? We'll bias your briefings." City/team entry. This is a *taste* of Pro (Local Team scope is Pro-only). It must preview the value and gate gracefully — a "Skip" must be obvious and guilt-free. Never feel like bait-and-switch.

## What must be on screen
- Page 1: name "The Sideline", value-prop line (candidates below), Get started.
- Page 2: 5 personas with a one-line description each (pull from `PRODUCT.md`), clear which is free.
- Page 3: a single text/picker affordance for city or team, a prominent **Skip**, a continue.
- A page indicator (3 dots). Back navigation between pages.

## Value-prop line — candidates (pick + offer ≤3 in copy/ONBOARDING.md)
- "Sound like you follow sports — without following sports."
- "The tea on sports, for people who don't watch sports."
- "Walk into any room with three things to say."

## What we don't want
- A feature-tour carousel of 5 screens.
- Sign-in, email, account anything (accountless app).
- A hard paywall during onboarding. Page 3 *previews* Pro; it does not sell here.
- Animated hero clutter. One calm symbol max.

## Constraints
- iOS 17 SwiftUI, dark mode, Dynamic Type AX5.
- Page 2's free-vs-Pro signaling must be consistent with the persona rail (`04`) and the gate (`08`) — don't invent a third lock language.
- Setting a team on page 3 stores it (`GoalSettings.favoriteCity/favoriteTeam`) even for free users — it just isn't *used* until Pro. Copy must be honest about that without killing momentum.

## Questions your mockup must answer
1. Does the persona pick on page 2 commit the home screen's starting persona, or just orient the user (and home defaults to Cocktail Party)? Recommend.
2. On page 3, what's the exact phrasing that previews Local Team value while making clear it's Pro — without feeling like a trick?
3. Is page 1's hero an SF Symbol, a wordmark, or the app icon rendered as an image? Try the strongest one.
4. Skip on page 3: text button, or a secondary-styled full-width button? Which gets less guilt?
