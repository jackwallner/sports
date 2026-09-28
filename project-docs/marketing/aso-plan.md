# aso-plan.md — Gist (Sports Small Talk) ASO Plan

> Written 2026-06-25. App: **Gist: Simple Sports Small Talk** (ID `6770138156`, repo `~/sports`). Methodology: `~/Desktop/aso.md`.

---

## 0. TL;DR

- **Positioning:** sports small-talk icebreakers for non-fans — NOT sports news/scores (ESPN/theScore wall).
- **Category creator:** owns #1 `sports small talk`; climbing `talking points` #63 (pop 56).
- **Verify ASC vs repo:** live SERP subtitle may be `Talking points for non-fans` while repo has `Icebreakers & conversation` — re-pull before ship.
- **US edit:** align subtitle to winner; swap field toward office/water-cooler vocabulary (~35% — single intentional release).

---

## 1. Competitor tiers

| Tier | Apps |
|---|---|
| **WALL** | Barstool, ClutchPoints, ESPN/Yahoo scores, SportsEngine — all news/scores SERPs |
| **WINNABLE PEERS** | **None** — sole occupant of sports-conversation niche |
| **ADJACENT** | Holsom / conversation-starter dating apps; sports radio |

**SERP FAIL:** `icebreaker`, `conversation starters`, `party games`, `sports recap` — wrong intent (dating/party/news).

---

## 2. US metadata change (staged)

**Change to:**
- subtitle → `Talking Points for Non-Fans`
- keywords → `beginners,explained,understand,questions,coworker,watercooler,office,party,fan,non,brief,casual,clueless`

| OUT | IN | Why |
|---|---|---|
| starters, dummies, recap, date, coworkers | watercooler, office, casual, clueless, coworker | starters redundant; dummies/recap wrong SERP; office = core use case |

95/100 chars.

---

## 3. Astro state (done 2026-06-25, tag migration complete)

**US:** 29 keywords · **global:** ~77. Field singletons + wall terms re-added; `sideline-live` retired.

| Tag | Keywords |
|---|---|
| `deployed` | beginners, explained, understand, questions, coworker, watercooler, office, party, fan, non, brief, casual, clueless |
| `target` | talking points, small talk, things to talk about, non sports fan, sports brief, sports recap, sports small talk |
| `wall` | sports news, sports scores, college football, conversation starters, icebreaker, party games |

Note on `talking points`: pop 56 SERP polluted by edu/political apps — subtitle placement is correct lever; don't over-chase as head term.

---

## 4. Rollout

Single metadata release (35% swap justified as alignment fix). Manual release. No locale expansion until US stabilizes.
