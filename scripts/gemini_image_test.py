#!/usr/bin/env python3
"""Throwaway probe: does Gemini image gen work for our card art, in a
consistent simple-newspaper-comic style? Saves PNGs we can eyeball."""

import base64
import json
import os
import sys
import time
import urllib.request

ENV_FILES = [".env", "SupabaseFunctions/.env"]


def load_key() -> str:
    if os.environ.get("GEMINI_API_KEY"):
        return os.environ["GEMINI_API_KEY"]
    for path in ENV_FILES:
        if not os.path.exists(path):
            continue
        for line in open(path):
            line = line.strip()
            if line.startswith("GEMINI_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("no GEMINI_API_KEY found")


# The fixed house style every card image shares. Glanceable, flat, friendly.
STYLE = (
    "Simple flat cartoon illustration in the style of a friendly newspaper comic. "
    "Bold clean black outlines, limited flat color palette of 2 to 3 colors on a warm "
    "cream paper background, minimal shapes, lots of negative space, one single clear "
    "subject centered, easy to read at a single glance, light gentle humor. "
    "No text, no words, no letters, no numbers, no logos, no brand marks, "
    "no real or recognizable people, no faces of real athletes. Vector-like, clean."
)

# Representative story subjects (no real names) to test style consistency.
SUBJECTS = [
    ("nfl_bench", "An American football helmet sitting alone on an empty stadium bench, sport: football."),
    ("nba_buzzer", "A basketball frozen mid-air just above the hoop at the buzzer, sport: basketball."),
    ("soccer_transfer", "A soccer ball with a tiny suitcase next to it, hinting at a player transfer, sport: soccer."),
]

MODEL = os.environ.get("IMAGE_MODEL", "gemini-2.5-flash-image")
OUT = "build/imgtest"


def generate(key: str, slug: str, subject: str) -> str:
    prompt = f"{subject}\n\n{STYLE}"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{MODEL}:generateContent?key={key}"
    )
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        body = json.loads(resp.read())

    parts = body.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    for part in parts:
        inline = part.get("inlineData") or part.get("inline_data")
        if inline and inline.get("data"):
            os.makedirs(OUT, exist_ok=True)
            path = f"{OUT}/{slug}.png"
            with open(path, "wb") as f:
                f.write(base64.b64decode(inline["data"]))
            return path
    # No image came back; dump what we got for debugging.
    raise RuntimeError("no image in response: " + json.dumps(body)[:800])


def main():
    key = load_key()
    print(f"model: {MODEL}")
    for i, (slug, subject) in enumerate(SUBJECTS):
        try:
            path = generate(key, slug, subject)
            print(f"  ok  -> {path}")
        except Exception as e:  # noqa: BLE001
            print(f"  FAIL {slug}: {e}")
        if i < len(SUBJECTS) - 1:
            time.sleep(31)  # free tier ~2 img/min; stay under it


if __name__ == "__main__":
    main()
