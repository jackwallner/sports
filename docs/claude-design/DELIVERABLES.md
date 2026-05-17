# What to send back

Drop each artifact into the matching folder with the **exact filename** below — the engineer wires these into specific Swift files without renaming. These are concrete to The Sideline's actual screens and components, not generic "site files."

```
output/
├── mockups/
│   ├── 01_onboarding_1_value.{md|png|svg}     → Sideline/Views/OnboardingView.swift (page 1)
│   ├── 01_onboarding_2_pick.*                 → OnboardingView (page 2, persona pick)
│   ├── 01_onboarding_3_team.*                 → OnboardingView (page 3, city/team, Pro taste)
│   ├── 02_today_briefing_populated.*          → Sideline/Views/TodayBriefingView.swift
│   ├── 02_today_briefing_skeleton.*           → TodayBriefingView (loading)
│   ├── 02_today_briefing_offline.*            → TodayBriefingView (cached/offline)
│   ├── 03_bullet_card_states.*                → Views/Components/BulletCard.swift (all 5 tag states + no-tag + no-tie-in)
│   ├── 04_persona_rail.*                      → Views/Components/PersonaChip.swift (selected / unselected / locked)
│   ├── 05_suggested_question.*                → Views/Components/SuggestedQuestionCard.swift
│   ├── 05_freshness_footer.*                  → Views/Components/SourceFootnote.swift (online + offline variant)
│   ├── 06_settings.*                          → Sideline/Views/SettingsView.swift
│   ├── 07_briefing_detail.*                   → Sideline/Views/BriefingDetailView.swift (sheet)
│   ├── 08_pro_gate.*                          → locked-chip tap behavior (preview, not wall)
│   ├── 09_paywall_fallback_card.*             → Sideline/Views/PaywallView.swift (hand-built fallback)
│   ├── 10_refresh_limit.*                     → TodayBriefingView inline upsell state
│   └── 11_icon_directions.*                   → App Icon (≥3 directions, no real logos)
├── tokens/
│   ├── COLORS.md          → pasted into Shared/Utilities/Theme.swift (real Swift, light+dark pairs)
│   ├── TYPOGRAPHY.md      → text-style mapping per element (TL;DR, talking point, tie-in, source…)
│   └── COMPONENTS.md      → reusable view specs: BulletCard, PersonaChip, SuggestedQuestionCard, SourceFootnote
├── symbols/
│   └── SF_SYMBOLS.md      → exact symbol name for each: 5 personas, 5 human-interest tags, freshness clock,
│                            source-link icon, offline icon, each empty/error state
├── copy/
│   ├── ONBOARDING.md      → every string across the 3 pages (incl. the Pro-taste line on page 3)
│   ├── EMPTY_STATES.md    → first-launch-no-network, fetch error, (no briefing yet)
│   ├── UPSELL.md          → locked-chip line, refresh-limit line, settings Pro row, paywall benefit bullets
│   ├── PAYWALL.md         → RevenueCat remote-config inputs (see 09 brief) + fallback-card strings
│   └── MICRO.md           → button labels, the 5 tag words, freshness string format, the offline affordance string
├── motion/
│   └── PERSONA_SWITCH.md  → timing/curve for the briefing cross-fade + refresh success cue + Reduce-Motion fallback
├── icon/
│   └── APP_ICON_BRIEF.md  → chosen direction rationale + construction (SF-Symbol-composed or simple mark, NO real logos)
└── HANDOFF_NOTES.md       → anything that doesn't fit a folder; flag any spec that can't be stock SwiftUI on iOS 17
```

## Format requirements per file type

### Mockups
**Preferred:** Markdown with ASCII layout sketches + annotated rationale — fastest for the engineer to translate to SwiftUI. SVG/PNG/Figma export also accepted; if raster, include a markdown sibling with rationale.

Each mockup file must include:
- Screen/component title and the exact target Swift file (from the tree above).
- Layout sketch.
- Component breakdown naming the SwiftUI primitives to compose (e.g. `ScrollView > VStack > [BulletCard] > SuggestedQuestionCard > SourceFootnote`).
- All required states (see `INVENTORY.md` — at minimum skeleton, populated, offline, error, free-limited, dark).
- Real copy strings (use the realistic sample briefing in `screens-to-design/02_today_briefing.md`, never lorem).
- Accessibility notes: VoiceOver reading order, the spoken form of the human-interest tag, Dynamic Type behavior, Reduce Motion.

### Tokens
SwiftUI-ready. `COLORS.md` must be a paste-able `extension Color { static let … }` (or `Theme` struct) block with **light and dark values for every token** — no orphan hex.

### Symbols
A flat table: semantic name → exact `Image(systemName:)` string → size/weight/rendering mode. If no SF Symbol fits, say so and pick the least-bad one (no custom icon will be made).

### Copy
One screen/surface per heading. Every visible string. Up to 3 variants per slot allowed — mark your recommendation.

### Motion
Step list with SwiftUI `Animation` API names (`.easeOut(duration:)`, `.spring(response:dampingFraction:)`). Reduce-Motion fallback mandatory.

## What NOT to send
- Pricing recommendations (RevenueCat owns pricing; you spec layout/copy only).
- Marketing landing-page or website mockups.
- App Store screenshots (separate job — noted in `SCREENSHOTS.md`).
- Mascots, illustration sets, or anything needing a custom asset pipeline beyond App Icon + one launch mark.
- Any real team/league/athlete imagery or names-as-logos.
- Anything requiring UIKit (except the already-planned `SFSafariViewController` for source links), Lottie, or third-party UI deps.

## How the engineer uses it
Each mockup becomes a feature branch (`design/02-today-briefing`), implemented in stock SwiftUI matching your component vocabulary, committed per screen, tested, TestFlight. If a spec can't be expressed in iOS 17 SwiftUI, the engineer comes back with a question — don't pre-compromise; give the real vision.
