# 02 — Today Briefing (the core screen)

**Target:** `Sideline/Views/TodayBriefingView.swift`
**Priority:** P0 — this *is* the product. Spend the most time here.
**Status:** Does not exist. Greenfield.

## Job
The user opens this on the walk into a room. In one read they get: a line to lead with, a few things to say, and one question to ask. They lock the phone and walk in confident. Skimmability beats completeness.

## Anatomy (top to bottom)
1. **Persona rail** — horizontal chips, selected one highlighted, locked ones visible (see `04`).
2. **Headline** — "What everyone's talking about" (the model writes this per briefing).
3. **TL;DR** — one sentence, the visual hero (out-ranks the headline; it's what they say out loud).
4. **Bullet cards** — 3–6 `BulletCard`s (see `03`).
5. **Suggested question card** — "Ask them this" (see `05`).
6. **Freshness footer** — "Updated 2h ago · 4 sources" / offline variant (see `05`).
- Pull-to-refresh at top. Tapping a bullet's source → `SFSafariViewController`. Tapping a bullet body → optional detail sheet (`07`).

## Use THIS sample content in every mockup (no lorem)
Persona: **Cocktail Party**
- Headline: *"What everyone's arguing about this week"*
- TL;DR: *"A beloved veteran quarterback got benched, the internet is melting down, and his replacement is a 23-year-old nobody had heard of last month."*
- Bullets:
  1. talking point: *"The team benched their longtime starter — fans are split between 'about time' and 'how dare they.'"* · tie-in: *"His wife posted a cryptic quote about loyalty, which did not help."* · tag: **Drama** — *"Locker-room sources are 'frustrated,' per reporters."* · source: "Veteran QB benched amid playoff push — The Athletic"
  2. talking point: *"The 23-year-old replacement is the feel-good story: undrafted, was working a normal job two years ago."* · tag: **Nice guy** — *"Donated his first big check to his old high school."* · source: "From warehouse shifts to starting QB — ESPN"
  3. talking point: *"A star player from another team called the benching 'disrespectful' and now those two teams play Sunday."* · tag: **Drama** — *"He has a history of saying the quiet part loud."* · source: "Rival star sounds off — Yahoo Sports"
- Suggested question: *"Do you think they made the right call, or did they just blow up their season?"*
- Footer: *"Updated 2h ago · 3 sources"*

## States (all required)
- **Skeleton:** shimmer placeholders for headline / TL;DR / 3 cards. This is a *fast network read*, not AI think-time — keep it brief and calm, no "thinking" copy.
- **Populated:** the above. Design first.
- **Offline / cached:** show the last cached briefing with a quiet `.ultraThinMaterial` banner — e.g. "Offline — showing the last update." Never a blocking error if a cache exists.
- **Error, no cache:** first launch, no network. `ContentUnavailableView`-style: symbol + "No briefing yet" + one line + Retry.
- **Free, refresh used:** pull-to-refresh again same day → inline upsell (see `10`), do not error.
- **Dark mode.**

## What we don't want
- Scores, standings, tables, tickers, team logos, player photos.
- Article body text. We show talking points and *link* the source — never reproduce.
- A dense feed. This is a short, finite briefing — when the user hits the question card, they're done.
- A long header/nav. Persona rail is the chrome.

## Constraints
- iOS 17 SwiftUI, dark mode, AX5 Dynamic Type, Reduce Motion.
- Source link must be reachable in one tap from every bullet (trust requirement).
- The whole briefing should be consumable one-handed, standing, in a hallway — vertical scroll, large tap targets, no horizontal reading except the persona rail.
- Persona switch re-fetches and cross-fades (see `motion/PERSONA_SWITCH.md`).

## Questions your mockup must answer
1. Headline vs TL;DR hierarchy — make the TL;DR unmistakably the thing to read first. Show the type/size decision.
2. Where does freshness live so it's a trust signal but not noise — pinned footer, under the headline, or both?
3. Does tapping a bullet open the detail sheet (`07`), or is the card self-sufficient and detail is cut for v1? Recommend.
4. How does the screen end? The question card should feel like a satisfying "you're ready" full-stop, not an abrupt scroll bottom.
