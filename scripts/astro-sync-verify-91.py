#!/usr/bin/env python3
"""Sync + verify all 91 Astro stores. Re-runs until each store has keywords."""
from __future__ import annotations

import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from astro_mcp import call, ping  # noqa: E402

MCP = "http://127.0.0.1:8089/mcp"
OUT = ROOT / "scripts" / "astro-keywords-by-store"
STORES_JSON = ROOT / "scripts" / "astro-stores-2026.json"
CONFIG = ROOT / "scripts" / ".astro-app.json"
MIN_KW = 15  # treat store as synced if at least this many keywords in Astro
GET_TIMEOUT = 90
STORE_SLEEP = 5
SYNC_RETRIES = 5


def app_id() -> str:
    return str(json.loads(CONFIG.read_text()).get("appId", "102"))


def planned_count(store: str) -> int:
    p = OUT / f"{store}.json"
    if p.exists():
        return int(json.loads(p.read_text()).get("keywordCount", 45))
    return 45


def keyword_count(store: str) -> int | None:
    for attempt in range(3):
        try:
            kws = call(MCP, "get_app_keywords", {"appId": app_id(), "store": store}, timeout=GET_TIMEOUT)
            return len(kws) if isinstance(kws, list) else 0
        except Exception:
            time.sleep(3 * (attempt + 1))
    return None


def sync_store(store: str) -> int:
    env = {**dict(__import__("os").environ), "PYTHONPATH": str(ROOT / "scripts"), "PYTHONUNBUFFERED": "1"}
    r = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "astro-sync-all-stores.py"), "--store", store],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
    )
    added = 0
    for line in r.stdout.splitlines():
        if "added ~" in line:
            try:
                added = int(line.split("added ~")[1].split()[0])
            except (IndexError, ValueError):
                pass
    return added


def main() -> None:
    if not ping(MCP):
        raise SystemExit("error: Astro MCP not reachable — open Astro and enable MCP")

    only_failed = "--retry-failed" in sys.argv
    failed_from_summary: set[str] = set()
    summary_path = OUT / "_summary.json"
    if only_failed and summary_path.exists():
        prev = json.loads(summary_path.read_text())
        failed_from_summary = {c for c, r in prev.get("stores", {}).items() if r.get("status") == "fail"}

    stores = [s["code"] for s in json.loads(STORES_JSON.read_text())["stores"]]
    if failed_from_summary:
        stores = [s for s in stores if s in failed_from_summary]
        print(f"Retrying {len(stores)} failed stores", flush=True)

    results: dict[str, dict] = {}
    if only_failed and summary_path.exists():
        results = json.loads(summary_path.read_text()).get("stores", {})

    for store in stores:
        if not only_failed and store in results and results[store].get("status") in ("ok", "synced"):
            continue
        n = keyword_count(store)
        if n is not None and n >= MIN_KW:
            print(f"OK   {store}: {n} keywords (skip sync)", flush=True)
            results[store] = {"count": n, "planned": planned_count(store), "status": "ok", "added": 0}
            time.sleep(STORE_SLEEP)
            continue

        print(f"SYNC {store}: had {n} keywords", flush=True)
        for attempt in range(1, SYNC_RETRIES + 1):
            sync_store(store)
            time.sleep(STORE_SLEEP)
            n = keyword_count(store)
            if n is not None and n >= MIN_KW:
                print(f"  -> {store}: {n} keywords (attempt {attempt})", flush=True)
                results[store] = {"count": n, "planned": planned_count(store), "status": "synced", "added": n}
                break
            print(f"  retry {attempt}/{SYNC_RETRIES} ({n} keywords)", flush=True)
            time.sleep(STORE_SLEEP)
        else:
            results[store] = {
                "count": n or 0,
                "planned": planned_count(store),
                "status": "fail",
                "added": 0,
            }
            print(f"FAIL {store}: only {n} keywords after {SYNC_RETRIES} attempts", flush=True)

    all_stores = [s["code"] for s in json.loads(STORES_JSON.read_text())["stores"]]
    if only_failed and summary_path.exists():
        full = json.loads(summary_path.read_text()).get("stores", {})
        full.update({k: v for k, v in results.items() if k in failed_from_summary})
        results = full
        stores = all_stores

    ok = sum(1 for r in results.values() if r.get("status") in ("ok", "synced") and r.get("count", 0) >= MIN_KW)
    summary = {
        "syncedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "appId": app_id(),
        "storeCount": len(all_stores),
        "verifiedOk": ok,
        "stores": {
            code: {
                "planned": info["planned"],
                "count": info["count"],
                "added": info.get("added", 0),
                "status": info["status"],
            }
            for code, info in sorted(results.items())
        },
    }
    (OUT / "_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"\nDone: {ok}/91 stores verified (≥{MIN_KW} keywords)", flush=True)
    if ok < 91:
        failed = [c for c, r in results.items() if r["status"] == "fail"]
        print(f"Failed: {', '.join(failed)}", flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
