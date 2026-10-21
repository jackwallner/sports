"""Composites a raw 1080 x 2400 emulator capture into a 1080 x 1920 Play screenshot.

Usage: python compose-screenshot.py <capture.png> <out.png> "<caption>"
A "|" in the caption forces a line break.
Needs Pillow and the macOS Georgia Bold font.
"""

import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1080, 1920
PAPER = (250, 246, 238)  # Theme.kt PAPER
INK = (21, 55, 42)  # Theme.kt cardPanel start
FONT = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
SHOT_HEIGHT = 1580
RADIUS = 44
TOP = 300


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def caption_lines(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont) -> list[str]:
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=font) > WIDTH - 140 and line:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line]


def compose(capture_path: str, out_path: str, caption: str) -> None:
    capture = Image.open(capture_path).convert("RGB")
    assert capture.size == (1080, 2400), capture.size
    width = round(capture.width * SHOT_HEIGHT / capture.height)
    shot = rounded(capture.resize((width, SHOT_HEIGHT), Image.LANCZOS), RADIUS)

    canvas = Image.new("RGB", (WIDTH, HEIGHT), PAPER)
    left = (WIDTH - width) // 2

    shadow = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, TOP + 18, left + width, TOP + 18 + SHOT_HEIGHT), RADIUS, fill=70
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.paste(Image.new("RGB", (WIDTH, HEIGHT), INK), (0, 0), shadow)
    canvas.paste(shot, (left, TOP), shot)
    ImageDraw.Draw(canvas).rounded_rectangle(
        (left, TOP, left + width - 1, TOP + SHOT_HEIGHT - 1), RADIUS, outline=(214, 206, 190), width=2
    )

    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT, 66)
    lines = [line for part in caption.split("|") for line in caption_lines(draw, part, font)]
    line_height = 82
    y = (TOP - line_height * len(lines)) // 2 + 4
    for line in lines:
        draw.text((WIDTH / 2, y), line, font=font, fill=INK, anchor="ma")
        y += line_height

    canvas.save(out_path, optimize=True)


if __name__ == "__main__":
    compose(sys.argv[1], sys.argv[2], sys.argv[3])
