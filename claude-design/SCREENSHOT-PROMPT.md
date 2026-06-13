# Paste this into Claude Design (attach the 5 raw-*.png files with it)

Produce exactly 5 finished PNGs and nothing else. No preamble, no
explanations, no alternates, no manifest, no follow-up questions.

## The one rule that overrides everything else

The five attached `raw-*.png` files are real device screenshots. **Use them
verbatim as the screen content.** Composite each raw image, unmodified and
uncropped, into a drawn iPhone frame on a marketing canvas. Do NOT redraw,
recreate, re-render, retype, restyle, or "idealize" any part of the app UI.
If a single pixel of app UI in your output was not copied from the raw file,
the output is wrong. Your job is the frame, the canvas, and the words around
the phone, nothing inside the phone.

## Canvas spec (the part that always goes wrong: exact pixels)

- Each output: **1320 × 2868 px, portrait**. This is the App Store Connect
  6.9-inch iPhone size and the only accepted iPhone size for this listing.
  PNG, RGB (sRGB), **no transparency**. If your renderer cannot hit exact
  pixels, match the 1320:2868 aspect ratio precisely at maximum resolution
  and never crop; I will resample to exact pixels afterward.
- The raws are 1320×2868 full-screen captures. Scale each raw down and place
  it inside a device frame: rounded-rect black bezel (continuous-corner,
  ~28-34 px stroke at this resolution), the raw's own rounded screen corners
  and Dynamic Island showing through. No hardware buttons or reflections
  needed; keep the frame minimal.

## House style (match my published apps' framed-screenshot look)

- Soft single-color canvas behind the phone: warm off-white `#F6F4EE`.
- Brand colors, from the app's real `Theme.swift` (`SidelineTheme`):
  green `#1F5C45` (brandPrimary), gold `#E0A21A` (brandAccent),
  ink for headline text `#1A1A1A`.
- Caption block: one big headline (heavy rounded sans, ~120-140 px cap
  height, 2 lines max) + one subline (~52-60 px, medium gray `#5A5A56`).
  Within each headline, one key phrase is set in brand green `#1F5C45`
  (frames 1, 3, 5) or gold-on-green treatment is NOT used; keep it simple.
- Layout alternates so the set reads as one family but not a wallpaper:
  - Frames 1, 3, 5: caption block on TOP of the canvas, phone below,
    phone bottom bleeding off the canvas edge; phone occupies ~72-76% of
    canvas height.
  - Frames 2, 4: phone on TOP (top edge bleeding off), caption block in a
    solid `#1F5C45` band across the bottom ~22% of the canvas, headline in
    white with the key phrase in gold `#E0A21A`, subline in white at 80%
    opacity.
- Identical margins, frame stroke, type sizes, and shadow (soft, subtle,
  y-offset down) across all five.

## Copy rules

- No em dashes anywhere. No competitor or league trademark names (Apple
  2.3.7): never ESPN, NFL, NBA, etc. in caption text.
- Use the captions below verbatim.

## Per-frame spec

| # | Raw (attached) | Output filename | Headline (accent phrase in *italics*) | Subline |
|---|---|---|---|---|
| 1 | `raw-1-deck-lead.png` | `store-1-deck-lead.png` | Sports small talk, *handled.* | One short daily briefing for people who don't follow sports. |
| 2 | `raw-2-talking-point.png` | `store-2-talking-point.png` | Say this. *Sound like you watched.* | Witty talking points, each backed by a real source. |
| 3 | `raw-3-card-back.png` | `store-3-backstory.png` | Flip it, *in case they ask.* | Every card carries its own backstory. |
| 4 | `raw-4-personas.png` | `store-4-personas.png` | Conversation starters *for your room.* | Cocktail party, office watercooler, date night, or the team your town won't stop talking about. |
| 5 | `raw-5-question.png` | `store-5-question.png` | Ask *one good question.* | Walk in ready. Put your phone away. |

"Accent phrase" = the italicized words above, rendered in the accent color
per the house style (not in italics).

## Output

Produce the five PNGs named `store-1-deck-lead.png` ... `store-5-question.png`,
in that order, as downloadable files, and stop.
