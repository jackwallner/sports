# Astro ASO phase B report — The Sideline

Run date: **2026-05-25** · Pipeline: `astro-global-aso-go-2026.md`

## Summary

| Item | Result |
|------|--------|
| App Store Connect ID | `6770138156` |
| Bundle ID | `com.jackwallner.sports` |
| Astro appId | `102` (Sports) |
| ASC draft version | `1.0` (`PREPARE_FOR_SUBMISSION`) |
| Locales optimized | **50** |
| ASC upload (API PATCH) | **50/50 ok** |
| deliver upload | **success** (metadata only, no screenshots) |
| Pull backup | `fastlane/metadata.bak.20260525-190702/` |
| Pre-upload backup | `fastlane/metadata.bak.pre-upload-20260525-190847/` |

## en-US before → after

| Field | Before (ASC pull) | After | Chars |
|-------|-------------------|-------|-------|
| **name** | `Casual Sports News - The Gist` | `The Sideline - Sports Gist` | 26/30 |
| **subtitle** | *(empty)* | `Talking points for non-fans` | 27/30 |
| **keywords** | *(empty)* | `conversation,starters,briefing,gossip,drama,news,teams,college,nfl,nba,mlb,nhl,nonfan` | 85/100 |

**Strategy:** Hero term **talking points** in subtitle (Astro pop 56 / diff 23). Keywords carry **conversation starters**, leagues, and non-fan intent without repeating name/subtitle tokens.

## All locales (keywords length / subtitle)

Full diff: `scripts/aso-locale-optimization-report.json`

| Locale | Subtitle (chars) | Keywords (chars) |
|--------|------------------|------------------|
| ar-SA | 23 | 68 |
| bn-BD | 21 | 74 |
| ca | 25 | 85 |
| cs | 21 | 81 |
| da | 26 | 75 |
| de-DE | 27 | 81 |
| el | 20 | 75 |
| en-AU | 27 | 85 |
| en-CA | 27 | 85 |
| en-GB | 27 | 85 |
| en-US | 27 | 85 |
| es-ES | 25 | 84 |
| es-MX | 25 | 82 |
| fi | 24 | 82 |
| fr-CA | 24 | 71 |
| fr-FR | 24 | 71 |
| gu-IN | 21 | 71 |
| he | 22 | 69 |
| hi | 20 | 76 |
| hr | 19 | 75 |
| hu | 22 | 81 |
| id | 27 | 81 |
| it | 20 | 91 |
| ja | 8 | 50 |
| kn-IN | 18 | 80 |
| ko | 9 | 44 |
| ml-IN | 22 | 85 |
| mr-IN | 17 | 76 |
| ms | 25 | 84 |
| nl-NL | 26 | 73 |
| no | 26 | 74 |
| or-IN | 21 | 75 |
| pa-IN | 17 | 71 |
| pl | 19 | 82 |
| pt-BR | 25 | 76 |
| pt-PT | 22 | 78 |
| ro | 23 | 77 |
| ru | 23 | 79 |
| sk | 20 | 82 |
| sl-SI | 19 | 82 |
| sv | 26 | 75 |
| ta-IN | 26 | 82 |
| te-IN | 21 | 81 |
| th | 20 | 77 |
| tr | 20 | 76 |
| uk | 26 | 76 |
| ur-PK | 19 | 73 |
| vi | 29 | 81 |
| zh-Hans | 7 | 43 |
| zh-Hant | 7 | 43 |

All 50 locales verified ≤30 name/subtitle, ≤100 keywords.

**True multi-language (2026-05-26):** Native `description` + `promotional_text` for all 50 locales via `scripts/aso-locale-content.json`. Brand name stays `The Sideline - Sports Gist` (English) on all storefronts; subtitles and keywords were already native. Re-uploaded to ASC draft `1.0` (API + deliver).

## Astro stores

- Target: **91** Search Ads countries — `_summary.json` **storeCount: 91**
- US keywords tracked in Astro: **69** (curated list + metadata tokens)
- Sync log: `scripts/astro-sync-all-stores.log` (partial MCP 500/timeout on some stores; re-run `./scripts/astro-sync-all-stores.sh` after ship if needed)
- Prune: `scripts/astro-prune-all-stores.log` (completed all 91)
- Tier-1 second pass: `scripts/astro-tier1-second-pass.log` (no rank/suggestion data prelaunch — expected)
- Per-store plans: `scripts/astro-keywords-by-store/`
- Competitor research: `scripts/astro-competitor-research.json`

## Upload confirmation

```
Patched 50 locale(s); created 0 new version localization(s).
Draft: 1.0
Draft appInfo locales: 50
Draft version locales: 50
fastlane deliver finished successfully
```

State: `scripts/.asc-state.json`

## Recommended ASC languages not yet added

All 50 deliver-supported locales are on disk and uploaded. No additional ASC metadata languages beyond the standard deliver set.

## Next: go refine

Calendar reminder **2026-06-08** (14 days): re-pull ASC → check Astro ranks → tune subtitle/keywords from rank data → `./scripts/asc-finish-missed.sh`.
