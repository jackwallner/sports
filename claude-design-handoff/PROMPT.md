# Paste this into Claude Design

You're improving the **app icon** and **visual system** for an iOS app called **The Sideline**.

**Read `README.md` in this folder first** — it explains what the app is, who the user is, and
the tone. Then look at `current/` (the real design primitives: `Theme.swift`, the launch color,
and the current app icon) and `source/` (copies of the real SwiftUI screens and components, plus
the data model in `Persona.swift` / `Briefing.swift` / `BriefingTag.swift`).

## Scope — read this before you start

- **In scope:** app icon, and a visual system = color palette, type scale, spacing, and the
  look of the core components.
- **Out of scope, do not produce:** full screen redesigns or new screen layouts, mood boards,
  brand-strategy/positioning decks, naming, or new dependencies. You tend to over-deliver — don't.
  If you're unsure whether something is in scope, it isn't.

---

## Part 1 — App icon

Deliver **3–5 distinct concepts**, each as a **1024×1024 PNG**.

Constraints:
- Must remain legible and recognizable at **60×60 px** (home-screen size). Test it small.
- Palette: stay anchored to the brand green (`#1F5C45`-ish, see `Theme.brandPrimary`) and the
  gold accent (`Theme.brandAccent`). You may propose one alternative palette concept, but at
  least 2 concepts should use the existing brand colors.
- Single clear focal idea — no scenes, no fine detail that dies when scaled down.

Metaphors to **avoid** (cliché *for this product specifically*):
- A whistle, a stopwatch, a scoreboard, or a generic ball — this app is **not** about playing
  or watching sports; it's about *conversation*.
- A speech bubble with "..." — generic chat-app energy.
- The current icon already uses a quotation mark over a line; you may evolve that idea, but at
  least 2 concepts should explore a genuinely different metaphor (e.g. the "sideline" / edge-of-
  the-field idea, a confident conversational gesture, a "prepared in a glance" idea).

Output the icons to `output/icon/concept-1.png` … `concept-N.png` plus a one-line caption each.

---

## Part 2 — Visual system (TWO STAGES — this gate is mandatory)

### Stage A — propose directions, then STOP

Give **2–3 *meaningfully different* directions** for the visual system. "Meaningfully different"
means different type personality / color treatment / density — not three shades of the same idea.
For **each** direction provide:
- **one paragraph** describing the direction (the feeling, the color/type move, why it fits a
  calm, witty, text-first reading app for non-fans), and
- **one sample component PNG** (render a talking-point card front or the lead gist card from
  `BriefingDeck` in that direction, at native iPhone screen width).

Then **STOP and wait for me to pick a direction.** Do not build tokens, do not produce the full
component set, do not write the rationale yet. Building everything before I choose wastes effort
on directions I'll reject.

### Stage B — only after I pick one direction

Once I name the direction, deliver:
1. **Design tokens as drop-in Swift** that replaces `current/Theme.swift` — same type
   (`enum SidelineTheme`), same property names where they already exist
   (`brandPrimary`, `brandAccent`, `amberText`, `tagNiceGuy`, `tagJerk`, `cardCornerRadius`),
   extended as needed (e.g. a type scale, spacing constants). It must compile as a replacement
   file. If the launch color changes, also give the updated `LaunchBackground.colorset` JSON.
2. **4–6 component PNGs** at native iPhone screen width, showing the chosen direction applied to:
   the rooms rail, the lead gist card, a talking-point card front (with a tag pill), a card back
   (backstory + source link), the suggested-question card, and the freshness footer.
3. A **1–2 page written rationale** (`output/rationale.md`) — the decisions and how they serve
   the audience and tone. Not a deck.

Put Stage B output in `output/system/` (tokens + JSON) and `output/system/components/` (PNGs).

---

## Output structure summary

```
output/
├── icon/            concept-1.png … (1024×1024) + captions
└── system/
    ├── Theme.swift          (Stage B — drop-in replacement)
    ├── LaunchBackground.colorset.json  (Stage B — only if launch color changes)
    ├── rationale.md         (Stage B)
    └── components/          (Stage A sample PNG, then Stage B set)
```
