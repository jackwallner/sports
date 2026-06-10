# Astro ASO strategy — The Sideline (global go 2026-05-25)

## App

| Field | Value |
|-------|-------|
| App Store name | The Sideline - Sports Gist |
| App Store Connect ID | `6770138156` |
| Bundle ID | `com.jackwallner.sports` |
| Astro | **Sports** — `appId` `102` |
| Config | `scripts/.astro-app.json` |
| ASC draft | `1.0` (`PREPARE_FOR_SUBMISSION`) |

---

## US highlights (Tier 1)

| Keyword | Pop | Diff | Placement |
|---------|-----|------|-----------|
| **talking points** | 56 | 23 | **subtitle** |
| **conversation starters** | 22 | 19 | keywords + promo text |
| **the gist** | 5 | 7 | name |
| briefing | 12 | 17 | keywords |
| sports conversation | 5 | 57 | track post-launch |

**Positioning:** Conversation fuel for people who don't follow sports — not scores, fantasy, or betting.

---

## ASC metadata (en-US)

| Field | Value | Chars |
|-------|-------|-------|
| **Name** | `The Sideline - Sports Gist` | 26/30 |
| **Subtitle** | `Talking points for non-fans` | 27/30 |
| **Keywords** | `conversation,starters,briefing,gossip,drama,news,teams,college,nfl,nba,mlb,nhl,nonfan` | 85/100 |

Validate: `python3 scripts/validate-asc-metadata.py`

---

## Pipeline scripts

```bash
# Full go (see docs/astro-global-aso-go-2026.md)
ASC_APP_VERSION=1.0 ./scripts/pull-appstore-metadata.sh
python3 scripts/aso-apply-locale-optimizations.py
./scripts/astro-sync-all-stores.sh
./scripts/astro-prune-all-stores.sh
python3 scripts/astro-tier1-second-pass.py
./scripts/asc-finish-missed.sh
```

---

## Astro weekly (~10 min)

1. Astro → **Sports** → US → sort by rank change
2. Filter **tier1-hero** / **priority** tags
3. Promote Tier 2 phrases with pop ≥ 10, diff ≤ 50 to subtitle experiments
4. Remove rank-1000 terms with pop ≤ 5 after 4 weeks

---

## Experiments (priority)

1. Ship with current subtitle (talking points hero)
2. Promotional text: mention "conversation starters"
3. **14 days post-ship:** A/B subtitle vs `Daily sports talking points`
4. Avoid: betting, fantasy, scores, ESPN — wrong audience

See also: `docs/astro-phase-b-report.md` · `docs/localization-aso.md`
