#!/usr/bin/env python3
"""
Remove Astro keywords not in the curated list (scripts/astro-keywords-us.json).

Uses MCP remove_keywords (undocumented in public Astro docs; works locally).

Usage:
  PYTHONPATH=scripts python3 scripts/astro-prune-keywords.py --dry-run
  PYTHONPATH=scripts python3 scripts/astro-prune-keywords.py --apply
"""
from __future__ import annotations

import argparse
import json
import re
import time
from pathlib import Path

from astro_mcp import call, remove_keywords

DEFAULT_MCP = "http://127.0.0.1:8089/mcp"
CONFIG_PATH = Path("scripts/.astro-app.json")
CURATED_PATH = Path("scripts/astro-keywords-us.json")
REMOVE_LIST_PATH = Path("scripts/astro-keywords-remove-in-astro-ui.txt")

# Always keep even if metrics look weak
MUST_KEEP = frozenset({
    "talking points",
    "conversation starters",
    "briefing",
    "conversation",
    "the gist",
    "sports conversation",
    "sports talking points",
})

RELEVANCE = re.compile(
    r"sports|nfl|nba|mlb|nhl|college|conversation|briefing|talking|gossip|drama|"
    r"fan|team|news|headline|digest|roundup|watercooler|office|party|casual|"
    r"sideline|gist|non.?fan|beginner|learn|cheat|question|culture|tea|locker|"
    r"football|basketball|baseball|hockey|mom|date|night|banter|chatter|topic|"
    r"icebreaker|explainer|brief",
    re.I,
)

BLOCKLIST = re.compile(
    r"apple health|healthkit|health app|daily tracker|free tracker|app tracker|"
    r"betting|fantasy|espn|bleacher report|the athletic|sports scores|nfl stats|"
    r"godaddy|itranslate|elsa|puzzle|restaurant|headache|calorie|pedometer|"
    r"dense sports|drama nice|angles drama|app pick|cocktail party$",
    re.I,
)

JUNK_STARTERS = frozenset(
    "the you for and not one pick open walk built when say read get their points "
    "into from with about have still but who are can want all every short includes "
    "unlocks gives people parents coworkers partners friends kids life party walking "
    "suddenly opinion quarterback original reporting keep enough context angles culture "
    "before after during between briefing one plain question every source just".split()
)


def load_remove_list() -> set[str]:
    if not REMOVE_LIST_PATH.exists():
        return set()
    out: set[str] = set()
    for line in REMOVE_LIST_PATH.read_text().splitlines():
        line = line.strip().lower()
        if line and not line.startswith("#"):
            out.add(line)
    return out


def is_junk(keyword: str, curated: set[str], explicit_remove: set[str]) -> bool:
    k = keyword.strip().lower()
    if k in curated or k in MUST_KEEP:
        return False
    if k in explicit_remove:
        return True
    if BLOCKLIST.search(k):
        return True
    if not RELEVANCE.search(k):
        return True
    words = k.split()
    if len(words) >= 4:
        return True
    if len(words) >= 2 and words[0] in JUNK_STARTERS:
        return True
    if len(words) >= 2 and (words[0], words[1]) in {
        ("news", "the"),
        ("gist", "sports"),
        ("talk", "for"),
        ("for", "non"),
        ("sports", "but"),
        ("sports", "pop"),
        ("pop", "culture"),
        ("culture", "talking"),
        ("talking", "points"),
        ("points", "before"),
        ("before", "you"),
    }:
        return True
    return False


def mcp_call(mcp_url: str, tool: str, arguments: dict, retries: int = 3) -> object:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            return call(mcp_url, tool, arguments, req_id=10 + attempt, timeout=240)
        except Exception as e:
            last = e
            time.sleep(2 * (attempt + 1))
    raise last  # type: ignore[misc]


def remove_batched(
    mcp_url: str,
    app_id: str,
    app_name: str,
    store: str,
    keywords: list[str],
) -> int:
    removed = 0
    for i in range(0, len(keywords), 15):
        batch = keywords[i : i + 15]
        try:
            result = remove_keywords(mcp_url, app_id, store, batch, app_name=app_name)
            for batch_result in result.get("batches", []):
                if isinstance(batch_result, dict):
                    removed += int(batch_result.get("removed", 0))
        except Exception as e:
            print(f"  batch {i // 15 + 1} error: {e}")
        time.sleep(1.0)
    return removed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Print removals only")
    parser.add_argument("--apply", action="store_true", help="Call remove_keywords")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Remove anything not in scripts/astro-keywords-us.json (+ MUST_KEEP)",
    )
    args = parser.parse_args()
    if not args.dry_run and not args.apply:
        args.dry_run = True

    cfg = json.loads(CONFIG_PATH.read_text())
    app_id = str(cfg["appId"])
    app_name = cfg.get("astroPlaceholderName", "Sports")
    store = cfg.get("store", "us")
    mcp = DEFAULT_MCP

    curated = set(k.lower() for k in json.loads(CURATED_PATH.read_text())["keywords"])
    explicit_remove = load_remove_list()

    raw = mcp_call(mcp, "get_app_keywords", {"appId": app_id, "store": store})
    tracked = [k["keyword"] for k in raw if isinstance(k, dict) and k.get("keyword")]

    if args.strict:
        keep_set = curated | MUST_KEEP
        to_remove = sorted(k for k in tracked if k.lower() not in keep_set)
    else:
        to_remove = sorted({k for k in tracked if is_junk(k, curated, explicit_remove)})
    to_keep = sorted({k.lower() for k in tracked if k.lower() not in {x.lower() for x in to_remove}})

    print(f"Tracked: {len(tracked)}")
    print(f"Curated target: {len(curated)}")
    print(f"Will keep: {len(to_keep)}")
    print(f"Will remove: {len(to_remove)}")

    if args.dry_run:
        print("\n--- REMOVE (first 40) ---")
        for k in to_remove[:40]:
            print(f"  - {k}")
        if len(to_remove) > 40:
            print(f"  ... +{len(to_remove) - 40} more")
        print("\n--- KEEP sample ---")
        for k in to_keep[:25]:
            print(f"  + {k}")
        return

    if not args.apply:
        return

    print("\nRemoving...")
    removed = remove_batched(mcp, app_id, app_name, store, to_remove)
    print(f"Removed (reported): {removed}")

    remaining = mcp_call(mcp, "get_app_keywords", {"appId": app_id, "store": store})
    n = len([k for k in remaining if isinstance(k, dict)])
    print(f"Remaining tracked: {n}")


if __name__ == "__main__":
    main()
