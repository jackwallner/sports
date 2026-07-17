#!/usr/bin/env python3
"""Build App Store creative: framed screenshots with headlines + app icon set.

Inputs:
  design/store-creative/backgrounds/bg-{1..5}.png  (AI-generated, ~852x1846)
  design/store-creative/raw-ui/store-{1..5}.png    (real UI captures, 1320x2868)
  design/store-creative/icon-master.png            (AI-generated icon, square)

Outputs:
  fastlane/screenshots/en-US/store-{1..5}.png      (1320x2868)
  design/store-creative/output/                     (same, for review)
  Sideline/Assets.xcassets/AppIcon.appiconset/icon-*.png
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CREATIVE = ROOT / "design" / "store-creative"
OUT_STORE = ROOT / "fastlane" / "screenshots" / "en-US"
OUT_REVIEW = CREATIVE / "output"
ICONSET = ROOT / "Sideline" / "Assets.xcassets" / "AppIcon.appiconset"

W, H = 1320, 2868
CREAM = (247, 241, 227)
BEZEL = (10, 26, 18)
SHADOW = (0, 0, 0, 110)

# (background, ui capture, headline lines)
FRAMES = [
    ("bg-1.png", "store-1.png", ["Know enough", "to join in."]),
    ("bg-2.png", "store-5.png", ["Get the story", "in minutes."]),
    ("bg-3.png", "store-3.png", ["Never blank", "on game day."]),
    ("bg-4.png", "store-2.png", ["The drama,", "decoded."]),
    ("bg-5.png", "store-4.png", ["Real stories,", "real sources."]),
]

FONT_SIZE = 128
LINE_GAP = 22
TEXT_TOP = 170
PHONE_TOP = 640
PHONE_W = 1060
SCREEN_RADIUS = 150
BEZEL_PAD = 26

ICON_SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]


def load_font(size: int) -> ImageFont.FreeTypeFont:
    try:
        font = ImageFont.truetype("/System/Library/Fonts/NewYork.ttf", size)
        font.set_variation_by_name("Semibold")
        return font
    except Exception:
        return ImageFont.truetype(
            "/System/Library/Fonts/Supplemental/Georgia Bold.ttf", size
        )


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *size], radius=radius, fill=255)
    return mask


def build_frame(bg_name: str, ui_name: str, lines: list[str], out_name: str) -> None:
    from PIL import ImageOps

    canvas = ImageOps.fit(
        Image.open(CREATIVE / "backgrounds" / bg_name).convert("RGB"), (W, H)
    )

    # Headline, centered, above the device
    draw = ImageDraw.Draw(canvas)
    font = load_font(FONT_SIZE)
    y = TEXT_TOP
    for line in lines:
        box = draw.textbbox((0, 0), line, font=font)
        line_w, line_h = box[2] - box[0], box[3] - box[1]
        draw.text(((W - line_w) / 2 - box[0], y - box[1]), line, font=font, fill=CREAM)
        y += line_h + LINE_GAP

    # Real UI scaled into a drawn device frame, bleeding off the bottom
    ui = Image.open(CREATIVE / "raw-ui" / ui_name).convert("RGB")
    scale = PHONE_W / ui.width
    ui = ui.resize((PHONE_W, round(ui.height * scale)), Image.LANCZOS)
    phone_w = PHONE_W + 2 * BEZEL_PAD
    phone_h = ui.height + 2 * BEZEL_PAD
    phone_x = (W - phone_w) // 2
    bezel_radius = SCREEN_RADIUS + BEZEL_PAD

    # Soft shadow behind the device
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [phone_x - 8, PHONE_TOP + 24, phone_x + phone_w + 8, PHONE_TOP + phone_h + 24],
        radius=bezel_radius,
        fill=SHADOW,
    )
    canvas = Image.alpha_composite(
        canvas.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(30))
    )

    phone = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    ImageDraw.Draw(phone).rounded_rectangle(
        [0, 0, phone_w, phone_h], radius=bezel_radius, fill=BEZEL
    )
    phone.paste(ui, (BEZEL_PAD, BEZEL_PAD), rounded_mask(ui.size, SCREEN_RADIUS))
    canvas.paste(phone, (phone_x, PHONE_TOP), phone)

    final = canvas.convert("RGB")
    assert final.size == (W, H), final.size
    final.save(OUT_STORE / out_name)
    final.save(OUT_REVIEW / out_name)
    print(f"wrote {out_name}")


def build_icons() -> None:
    master = Image.open(CREATIVE / "icon-master.png").convert("RGB")
    if master.width != master.height:
        side = min(master.size)
        master = master.crop((0, 0, side, side))
    for size in ICON_SIZES:
        master.resize((size, size), Image.LANCZOS).save(ICONSET / f"icon-{size}.png")
    print(f"wrote {len(ICON_SIZES)} icon sizes")


def main() -> None:
    OUT_REVIEW.mkdir(parents=True, exist_ok=True)
    for i, (bg, ui, lines) in enumerate(FRAMES, start=1):
        build_frame(bg, ui, lines, f"store-{i}.png")
    build_icons()


if __name__ == "__main__":
    main()
