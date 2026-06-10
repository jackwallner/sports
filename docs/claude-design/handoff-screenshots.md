# App Store Screenshot Handoff — The Sideline v1

## Context

The app has a Tinder-style swipe deck of story cards + a "Your Move" question card. The persona rail lets the user pick their social context. This is a conversation-prep app for non-fans, not a scores app. Screenshots need to communicate "I can walk into any room and sound like I know what I'm talking about."

## Launch args for capture

Use these debug flags when running on simulator:

```
-SidelineScreenshot -SidelineScreenshotMode -SidelineForcePro -SidelineDeckStart <N> -SidelinePersona <persona>
```

Pre-set `UserDefaults` args to skip onboarding: `-hasCompletedOnboarding 1 -hasSeenOnboardingPaywall 1`

## Screenshot layout

Default: 6.7" iPhone (1290×2796 portrait). Produced 5 at a time for each device frame. Every screenshot includes safe area content only — no device frame in the capture. Fastlane frames later.

## What to screenshot — 5 slots

### 1. The deck — first story card (hero)

**Launch:** `-SidelineDeckStart 0 -SidelinePersona cocktailParty`

**What:** The front card of the swipe deck. Shows the full-bleed gradient hero area with the TL;DR talking point text, the sport chip (e.g. NFL), and the human-interest tag pill (e.g. "drama" or "nice guy"). Footer visible with the backup detail text and "Learn More" button.

**Purpose:** This IS the product. User sees exactly what they get — a scannable, sourced talking point they can say out loud. No tutorial, no onboarding, no login — just the card.

**Key ASO keywords to surface visually:** The card should show a recognizable sport context (NFL/NBA) and the conversational angle (tag pill) to visually confirm "sports conversation" / "sports talk" / "sports gossip" / "sports icebreaker" keywords.

### 2. The deck — stacked cards (depth visualization)

**Launch:** `-SidelineDeckStart 0 -SidelinePersona cocktailParty` (capture at state where multiple cards visible)

**What:** Show the Tinder-style card stack to communicate there are multiple talking points per briefing. The top card partially swiped or the stack visible with 3 cards layered. The circular swipe mechanic signals "more than one thing to say."

**Purpose:** Communicate depth of content — this isn't just one fact, it's a full set of talking points plus the question card.

### 3. The question card ("Your Move")

**Launch:** `-SidelineDeckStart 5 -SidelinePersona cocktailParty` (deck start past story cards to land on question)

**What:** The gold-gradient question card showing the suggested question to ask a fan. "Ask a fan to keep it going." text in footer.

**Purpose:** Shows the "bridge" — after you read the points, here's how you keep the conversation going. This is the differentiated feature that makes it not just a trivia/news app.

### 4. Persona rail — showing multiple contexts

**Launch:** `-SidelinePersona cocktailParty` (not ForcePro, so Pro personas show locked)

**What:** The persona rail at top with all 5 persona chips visible. Cocktail Party selected (green filled), others with capsule borders. Pro chips (Office, Date Night, Sports Mom, Local Team) show lock icon. The persona rail is scrolled to show variety.

**Purpose:** Communicates breadth — this app works for multiple social situations, not just one. The locked chips create curiosity about Pro without being pushy.

### 5. Briefing overview / alternative context

**Launch:** `-SidelineDeckStart 0 -SidelinePersona officeWatercooler`

**What:** Same as screenshot 1 but with the Office Watercooler persona selected (Pro unlocked via ForcePro flag). Shows the TL;DR card for a different context. May show a slightly different tag or sport chip.

**Purpose:** Proves the app adapts to context (cocktail party ≠ office ≠ date night). Also gives Apple Search Ads a second visual variant for the same keywords.

## Visual requirements for each screenshot

| # | Title text (overlay on screenshot) | Subtitle text | What to show |
|---|---|---|---|
| 1 | "One card. One thing to say." | "Talking points from real reporting — not hot takes." | Hero card front, full-bleed, sport chip + tag pill |
| 2 | "Swipe for more." | "Every briefing gives you 3-6 points + a question to ask." | Card stack visible (3 cards layered) |
| 3 | "Now keep it going." | "End with one question a fan will love to answer." | Gold question card |
| 4 | "Every conversation, covered." | "Cocktail Party, Office, Date Night, Sports Mom, Local Team." | Persona rail with 5 chips, variety visible |
| 5 | "Your room. Your angle." | "Same day, different context — pick the one that fits." | Office persona in full briefing |

## Typography for overlay text (approximate)

All screenshots should use SF Pro (system font). Title text is bold, 32-36pt. Subtitle is regular, 17-19pt. Text overlay should sit below the safe area content or in a consistent region — not covering the card's hero text. Use a semi-transparent backdrop if the screenshot content is light.

## What NOT to show

- No logo or "The Sideline" branding in screenshots (Apple guidelines discourage watermarking)
- No pricing, rating prompts, or paywall screens
- No empty states, loading states, or error states
- No settings screen
- No SafariView sheets showing source links
- No device frame, status bar, or notch artwork (fastlane handles this)

## Output for Claude Design

Produce mockups showing the content state for each of the 5 screenshots — not pixel-perfect screenshots (those come from simulator capture). Show:
1. The layout/positioning of content vs. overlay text
2. Which card content to have loaded (sport context, tag type, question text)
3. Color treatment for hero gradient, footer, persona rail per each shot

Label each mockup with its corresponding screenshot slot number and launch args.

## After capture handoff

Developer will:
1. Boot simulator with exact launch args
2. `xcrun simctl io booted screenshot <path>.png`
3. Fastlane `frameit` for device frames
4. Upload via `SKIP_SCREENSHOTS=false ./scripts/upload-appstore-metadata.sh`
