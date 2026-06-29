#!/usr/bin/env python3
"""Refresh Gist keyword fields only: validated conversation-intent set, per locale.

Keeps the working name ("Gist: Simple Sports Small Talk") and the region-aware
subtitles already in fastlane (Footy/Football/Hockey chat; "Talking points for
non-fans" — the latter is climbing 123->31 on pop-56 `talking points`).

Only the keyword field changes: swap league-name / scores / news walls (wrong intent,
ESPN/official-app territory) for the conversation-intent set (recap, debate, roundup,
headlines, insider, highlights, ...). Source map reused from
aso-apply-locale-optimizations.py (its SUBTITLES/BRAND_NAME rewrite is intentionally
NOT used — BRAND_NAME would clobber the working app name).
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"

spec = importlib.util.spec_from_file_location(
    "aopt", str(Path(__file__).parent / "aso-apply-locale-optimizations.py")
)
aopt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aopt)
KEYWORDS = aopt.KEYWORDS
dedupe_keywords = aopt.dedupe_keywords

# Local-color terms worth keeping in-market (conversation intent, not walls).
EXTRA = {
    "en-GB": ["banter"],
    "en-AU": ["banter", "mates"],
}


def trim_keywords(s: str, limit: int = 100) -> str:
    s = s.replace(", ", ",")
    if len(s) <= limit:
        return s
    parts = s.split(",")
    while parts and len(",".join(parts)) > limit:
        parts.pop()
    return ",".join(parts)


def unicode_dedupe(csv: str, indexed_text: str) -> str:
    low = indexed_text.lower()
    out, seen = [], set()
    for raw in csv.split(","):
        t = raw.strip()
        k = t.lower()
        if t and k not in low and k not in seen:
            out.append(t)
            seen.add(k)
    return ",".join(out)


def main() -> None:
    report = {}
    for loc_dir in sorted(p for p in META.iterdir() if p.is_dir() and p.name != "review_information"):
        loc = loc_dir.name
        if loc not in KEYWORDS:
            continue
        name = (loc_dir / "name.txt").read_text(encoding="utf-8").strip() if (loc_dir / "name.txt").exists() else ""
        sub = (loc_dir / "subtitle.txt").read_text(encoding="utf-8").strip() if (loc_dir / "subtitle.txt").exists() else ""
        raw = KEYWORDS[loc].replace("debste", "debatte")  # fix source typo
        if loc in EXTRA:
            raw = raw + "," + ",".join(EXTRA[loc])
        kw = dedupe_keywords(name, sub, raw)
        kw = unicode_dedupe(kw, f"{name} {sub}")
        kw = trim_keywords(kw)
        old = (loc_dir / "keywords.txt").read_text(encoding="utf-8").strip() if (loc_dir / "keywords.txt").exists() else ""
        (loc_dir / "keywords.txt").write_text(kw + "\n", encoding="utf-8")
        report[loc] = {"subtitle": sub, "old": old, "new": kw, "len": len(kw)}
    out = ROOT / "scripts" / "aso-gist-keywords-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Updated keywords for {len(report)} locales -> {out}")


if __name__ == "__main__":
    main()
