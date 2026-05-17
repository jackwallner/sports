# The Sideline — Product Snapshot

## In one line
Conversation fuel for people who don't follow sports but have to talk to people who do.

## Who it's for
- The non-fan with a fan in their life: a parent of a sports-obsessed kid, a partner, a new employee at a sports-mad office.
- Not fans. Fans don't need this and will find it shallow — that's fine, they're not the buyer.
- iPhone-first. Read in under a minute, standing up, before walking into a room.

## Core loop
1. Pick a context ("persona") — the *room* you're about to be in.
2. Read today's briefing: one-line TL;DR → 3–6 talking points → one question to ask.
3. Optionally tap a bullet's source to verify / read the real headline.
4. Walk in, say the thing, ask the question, look like you pay attention.

## The personas (contexts)
| Persona | Free? | The voice it writes in |
|---|---|---|
| Cocktail Party | **Free** | Broad, witty, cross-sport. One line you can drop anywhere. Light gossip. |
| Sports Talk for Moms | Pro | Warm, zero jargon, framed as "ask your kid about…". |
| Office Watercooler | Pro | Safe, current, mildly opinionated takes for coworkers. |
| Date Night | Pro | One charming story + a follow-up question to seem interested. |
| Local Team | Pro | Biased to the user's city/team. Storylines from their market. |

## The briefing (what's on the screen)
- **Headline** — what everyone's talking about right now.
- **TL;DR** — one sentence the user can lead with verbatim.
- **3–6 bullets**, each: a plain-language talking point; optional pop-culture tie-in (the celebrity/feud/movie angle); optional **human-interest tag** — `nice guy` / `jerk` / `redemption` / `drama` / `neutral` — with a one-line why; a source headline + link.
- **Suggested question** — an open question to ask a fan to keep the conversation alive.
- **Freshness** — "Updated 2h ago" + the sources behind it.

## Free vs Pro
- **Free:** Cocktail Party persona only. One fresh briefing per calendar day. National scope.
- **Pro:** All five personas. Fresh briefings 3×/day. Local-team personalization (city/team scope).

## Tone of voice
- Witty, warm, a little gossipy — like a clued-in friend texting you before the party.
- Never lad-y, never ESPN-anchor, never stats-nerd.
- Plain language. "The quarterback everyone loved just got benched and people are furious" — not "QBR regression after Week 3."
- The "nice guy / jerk" framing is playful, not cruel. It's tea, not character assassination.
- Confident brevity. The user is busy and slightly anxious; respect both.

## What it deliberately is not
- Not a scores app. No scoreboards, standings, box scores, or stats ever.
- Not a news reader. We surface talking points and link out for the source — we never reproduce articles.
- Not a fantasy / betting tool.
- Not social. No accounts, no feed, no sharing-back, no comments.
- Not a fan app. If it makes a real fan feel catered to, we drifted.

## Where we are in the lifecycle
Day zero. No code yet — scaffolding begins alongside this design pass. Backend (Supabase + Claude generating cached, source-cited briefings 3×/day, shared across all users) is specced and approved. Your designs are implemented by another Claude instance reading this folder as source of truth.
