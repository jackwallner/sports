# Design Brief — The Sideline v1 (first design pass, greenfield)

## Why this exists

There is no app yet. The engineering plan is approved and scaffolding starts in parallel. We need the visual and interaction design to lead, not trail, the build — so the implementing engineer (another Claude instance) builds *your* screens, not stock `Form`s we redesign later.

The product's whole reason to exist is **social confidence**. The user is someone who feels slightly outside a conversation — a mom whose son won't stop talking about a trade, a new hire at a sports-obsessed office. The app's job is to make them feel *armed and at ease in 20 seconds*. The design has to feel calm, quick, and a little witty — never like homework, never like ESPN, never like a stats terminal.

## The three jobs we need design help with, in order

### 1. Nail the 20-second "I've got this" moment (Today Briefing)
This is the screen the user opens before walking into the room. Persona chips at top, then a scannable briefing: a one-line TL;DR they can lead with, 3–6 bullet "talking points," each with an optional pop-culture tie-in and an optional human-interest tag (nice guy / jerk / redemption / drama), and one "ask them this" question at the bottom.

**Goal:** A non-fan can read it once, lock the phone, and walk in with three things to say and one question to ask. Skimmability is everything. The "nice guy / jerk" tag is the emotional hook — make it land without feeling mean.

**Deliverable:** mockups for Today Briefing (populated), the `BulletCard` component in all tag states, the persona chip rail (including locked chips), the suggested-question card, and the "updated 2h ago + source" footer.

### 2. Make Pro feel like *more conversations*, not a paywall
Free = one persona (Cocktail Party), one fresh briefing per day. Pro = all five personas, fresh 3×/day, local-team personalization. Locked personas live right in the chip rail the user is already scrolling.

**Goal:** The locked chip is an invitation ("here's the office-watercooler version") not a wall. The paywall reads as "five rooms instead of one," not a pricing chart.

**Deliverable:** locked-chip treatment + tap behavior, the "you already refreshed today" upsell state, the RevenueCat remote-paywall input spec (we don't hand-code the paywall), and the fallback paywall card (shown when RevenueCat isn't configured).

### 3. Make onboarding pick the right room fast
Three short pages: value prop → pick your starting context → (optional) set your city/team. Free users land on Cocktail Party regardless; the favorite-team page is a *taste* of Pro.

**Goal:** Under 15 seconds to first briefing. The persona-pick page should make someone go "oh — *that's* the one I need."

**Deliverable:** the 3 onboarding pages, the persona-pick interaction, and how the favorite-team page previews-but-gates Pro without feeling like a bait-and-switch.

## Things to deliberately NOT design

- Any account / sign-in / profile screen — the app is accountless.
- A box-score, scoreboard, standings, or stats view — antithetical to the product.
- A news-feed / article-reader — we show talking points, never article bodies.
- Watch app or widgets — out of scope for v1.
- Settings beyond the brief in `screens-to-design/06_settings.md`.

## Constraints that limit your fun

- The paywall is RevenueCat remote-configured: you design the *inputs* (template, hero, headline, bullets), not custom paywall SwiftUI. The in-app fallback card *is* hand-built — design that fully.
- Every bullet must visibly carry its source headline + tappable link. You may make it quiet, not invisible.
- No real team logos, league marks, or athlete likenesses anywhere (legal). Use SF Symbols / generic forms only — including in the App Icon.
- English only, copy is plain text in views (no localization budget) — but write copy that wouldn't embarrass us.

## Success criteria, ranked

1. A first-time user reaches a readable briefing in under 20 seconds and screenshots it to share the "what a jerk" line.
2. A free user taps a locked persona chip and understands exactly what they'd get.
3. The briefing is skimmable enough to consume one-handed, standing, in a hallway.
4. Nobody mistakes this for a scores app.

If you can only deliver one job, deliver Job 1.
