#!/usr/bin/env python3
"""Validate Gist's Google Play listing copy under android/play-assets/metadata/android.

Checks every locale folder for Play's limits (title 30, short 80, full 4000),
the house rules (no em dashes, no prices, no Apple wording, no promo words in
the title, no medical or betting claims), the Gist brand in every title, the
policy links and Google Play billing paragraph, and, for non-English locales,
a plain statement that the app itself is in English. When the gitignored
.play-live-listing.json export is present, en-US must match it exactly.
Exit 1 on any failure.

Usage: scripts/validate-play-listing.py [--root DIR]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ROOT = REPO / "android/play-assets/metadata/android"
LIVE = REPO / ".play-live-listing.json"
LIMITS = {"title.txt": 30, "short_description.txt": 80, "full_description.txt": 4000}
# Play language codes accepted by the Publishing API (fastlane supply list).
PLAY_LANGS = set(
    "af am ar az-AZ be bg bn-BD ca cs-CZ da-DK de-DE el-GR en-AU en-CA en-GB en-IN "
    "en-SG en-US en-ZA es-419 es-ES es-US et eu-ES fa fi-FI fil fr-CA fr-FR gl-ES "
    "hi-IN hr hu-HU hy-AM id is-IS it-IT iw-IL ja-JP ka-GE km-KH kn-IN ko-KR ky-KG "
    "lo-LA lt lv mk-MK ml-IN mn-MN mr-IN ms ms-MY my-MM ne-NP nl-NL no-NO pl-PL "
    "pt-BR pt-PT rm ro ru-RU si-LK sk sl sr sv-SE sw ta-IN te-IN th tr-TR uk vi "
    "zh-CN zh-HK zh-TW zu".split()
)
TITLE_BANNED = re.compile(r"\b(free|best|top|#1|new|sale)\b", re.I)
PRICE = re.compile(r"[$€£¥₹]\s?\d|\d[.,]\d\d\s?(?:€|zł|kr|lei|Kč|₺|₽|₴)")
APPLE = re.compile(r"\b(?:Apple|App Store|iPhone|iPad|iCloud)\b", re.I)
MEDICAL = re.compile(r"\b(treat|treats|treatment|cure|cures|diagnos\w*)\b", re.I)
URL_OK = re.compile(r"https://jackwallner\.github\.io/\S+")
PRIVACY_URL = "https://jackwallner.github.io/sports/privacy-policy.html"
TERMS_URL = "https://jackwallner.github.io/sports/terms.html"
# The word for "English" each non-English listing must use when it says the app is in English.
ENGLISH_WORD = {
    "de-DE": "Englisch", "fr-FR": "anglais", "fr-CA": "anglais", "es-ES": "inglés",
    "es-419": "inglés", "es-US": "inglés", "pt-BR": "inglês", "pt-PT": "inglês",
    "it-IT": "inglese", "nl-NL": "Engels", "sv-SE": "engelska", "no-NO": "engelsk",
    "da-DK": "engelsk", "fi-FI": "englan", "pl-PL": "angiel", "cs-CZ": "angličtin",
    "sk": "angličtin", "sl": "angleš", "hr": "engleskom", "hu-HU": "angol",
    "ro": "englez", "el-GR": "αγγλικά", "tr-TR": "İngilizce", "ru-RU": "английском",
    "uk": "англійською", "ar": "الإنجليزية", "iw-IL": "באנגלית", "hi-IN": "अंग्रेज़ी",
    "bn-BD": "ইংরেজি", "mr-IN": "इंग्रजी", "ta-IN": "ஆங்கில", "te-IN": "ఇంగ్లీష్",
    "kn-IN": "ಇಂಗ್ಲಿಷ್", "ml-IN": "ഇംഗ്ലീഷ", "id": "bahasa Inggris", "ms": "bahasa Inggeris",
    "ms-MY": "bahasa Inggeris", "th": "ภาษาอังกฤษ", "vi": "tiếng Anh", "ja-JP": "英語",
    "ko-KR": "영어", "zh-CN": "英文", "zh-TW": "英文", "zh-HK": "英文", "ca": "anglès",
}


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8").strip() if p.exists() else ""


def check_text(name: str, text: str, limit: int) -> list[str]:
    errs: list[str] = []
    if not text or len(text) > limit:
        errs.append(f"{name} {len(text)}/{limit}")
    if "—" in text:
        errs.append(f"{name} has an em dash")
    if re.search("[­​﻿]", text):
        errs.append(f"{name} has an invisible character")
    if m := PRICE.search(text):
        errs.append(f"{name} looks like it has a price: {m.group(0)!r}")
    if m := APPLE.search(URL_OK.sub("", text)):
        errs.append(f"{name} mentions Apple wording: {m.group(0)!r}")
    if m := MEDICAL.search(text):
        errs.append(f"{name} has a medical claim word: {m.group(0)!r}")
    if name != "full_description.txt" and "\n" in text:
        errs.append(f"{name} spans lines")
    return errs


def check(locale_dir: Path) -> list[str]:
    loc = locale_dir.name
    errs: list[str] = [] if loc in PLAY_LANGS else [f"unknown Play language code {loc}"]
    for name, limit in LIMITS.items():
        if not (locale_dir / name).exists():
            errs.append(f"missing {name}")
            continue
        errs += check_text(name, read(locale_dir / name), limit)
    title = read(locale_dir / "title.txt")
    full = read(locale_dir / "full_description.txt")
    if TITLE_BANNED.search(title):
        errs.append(f"title has a promo word: {title!r}")
    if not title.startswith("Gist"):
        errs.append(f"title does not lead with the Gist brand: {title!r}")
    if "Google Play" not in full:
        errs.append("full description lacks the Google Play billing paragraph")
    for url in (PRIVACY_URL, TERMS_URL):
        if url not in full:
            errs.append(f"full description lacks {url}")
    if not loc.startswith("en"):
        word = ENGLISH_WORD.get(loc)
        if word is None:
            errs.append("no English-language marker defined for this locale")
        elif word.lower() not in full.lower():
            errs.append(f"full description does not say the app is in English ({word!r})")
    return errs


def check_live(root: Path) -> list[str]:
    """en-US (and any other live locale) must match the Play export exactly."""
    if not LIVE.exists():
        return []
    errs: list[str] = []
    fields = {"title": "title.txt", "shortDescription": "short_description.txt", "fullDescription": "full_description.txt"}
    for listing in json.loads(LIVE.read_text(encoding="utf-8")).get("listings", []):
        loc = listing["language"]
        for key, name in fields.items():
            if read(root / loc / name) != listing.get(key, "").strip():
                errs.append(f"{loc}/{name} differs from the live Play listing")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=ROOT)
    args = ap.parse_args()
    bad = 0
    dirs = sorted(d for d in args.root.iterdir() if d.is_dir())
    for d in dirs:
        errs = check(d)
        t, s, f = (read(d / n) for n in LIMITS)
        print(f"{'OK ' if not errs else 'BAD'} {d.name:7} t{len(t):>3} s{len(s):>3} f{len(f):>5}  {t}")
        for e in errs:
            print(f"      - {e}")
        bad += bool(errs)
    live_errs = check_live(args.root)
    for e in live_errs:
        print(f"BAD live: {e}")
    print(f"\n{len(dirs)} locales, {bad} with problems" + (f", {len(live_errs)} live mismatches" if live_errs else ""))
    return 1 if bad or live_errs else 0


if __name__ == "__main__":
    sys.exit(main())
