#!/usr/bin/env python3
"""Validate App Store Connect metadata character limits (en-US)."""
from __future__ import annotations

from pathlib import Path

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100}
META = Path("fastlane/metadata/en-US")


def main() -> None:
    ok = True
    for field, limit in LIMITS.items():
        path = META / f"{field}.txt"
        text = path.read_text().strip() if path.exists() else ""
        n = len(text)
        status = "OK" if n <= limit else "OVER"
        if n > limit:
            ok = False
        print(f"{field}: {n}/{limit} {status}")
        if field == "keywords":
            tokens = [t for t in text.split(",") if t]
            print(f"  tokens ({len(tokens)}): {', '.join(tokens)}")
        else:
            print(f"  {text!r}")
    if not ok:
        raise SystemExit(1)
    print("\nAll fields within ASC limits.")


if __name__ == "__main__":
    main()
