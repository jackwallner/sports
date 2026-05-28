# App Store Metadata

## App Information

| Field | Value |
|---|---|
| App Name | The Sideline - Sports Gist (30 char max) |
| Bundle ID | `com.jackwallner.sports` |
| Subtitle | Talking points for non-fans (30 char max) |
| Primary Category | Sports |
| Secondary Category | Lifestyle |
| Price | Free |
| Copyright | 2026 Jack Wallner |

## Description

The Sideline gives you quick sports pop-culture talking points before you walk into the room.

It is built for people who do not follow sports but still have sports people in their life: coworkers, partners, friends, kids, parents, and everyone at the party who suddenly has an opinion about a quarterback.

Open the app, pick the room you are walking into, and read a short briefing:

- One plain-English TL;DR you can say out loud.
- 3 to 6 talking points framed for non-fans.
- Pop-culture angles, drama, nice-guy stories, and redemption arcs.
- A source link on every point so you can check the original reporting.
- One question to ask a fan when you want to keep the conversation going.

The Sideline is not a scores app, betting app, fantasy app, or dense sports news feed. No standings. No stat tables. No team-logo wallpaper. Just enough context to feel included in the conversation.

The free version includes the Cocktail Party context with a daily national briefing.

The Sideline Pro unlocks all contexts, fresher briefings up to 3 times a day, and Local Team personalization.

## Promotional Text

Sports conversation fuel for people who do not follow sports. Read one short briefing, ask one good question, and walk in ready.

## Keywords (100 characters max — comma-separated, no spaces)

```
conversation,starters,briefing,gossip,drama,sports,news,teams,college,nfl,nba,mlb,nhl,nonfan
```

(92 characters, 15 tokens.) Hero term **talking points** lives in the **subtitle**; Apple de-duplicates repeats across name/subtitle/keywords, so the keyword field covers **conversation starters**, leagues, and intent tokens instead.

Validate locally: `python3 scripts/validate-asc-metadata.py`

**Previously live on ASC:** name `Casual Sports News - The Gist`, empty keywords — see `fastlane/metadata.bak.*` after pull.

## URLs

- Support URL: `https://jackwallner.github.io/sports/support.html`
- Privacy Policy URL: `https://jackwallner.github.io/sports/privacy-policy.html`
- Terms URL: `https://jackwallner.github.io/sports/terms.html`
