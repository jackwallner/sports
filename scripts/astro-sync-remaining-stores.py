#!/usr/bin/env python3
"""Sync remaining Astro stores one at a time (resilient to MCP timeouts)."""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scripts" / "astro-keywords-by-store"
STORES_JSON = ROOT / "scripts" / "astro-stores-2026.json"


def main() -> None:
    stores = [s["code"] for s in json.loads(STORES_JSON.read_text())["stores"]]
    done = {p.stem for p in OUT.glob("*.json") if p.name != "_summary.json"}
    env = {**dict(__import__("os").environ), "PYTHONPATH": str(ROOT / "scripts"), "PYTHONUNBUFFERED": "1"}
    for store in stores:
        if store in done:
            print(f"skip {store}", flush=True)
            continue
        print(f"=== syncing {store} ===", flush=True)
        r = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "astro-sync-all-stores.py"), "--store", store],
            cwd=ROOT,
            env=env,
        )
        if r.returncode != 0:
            print(f"FAIL {store} rc={r.returncode}", flush=True)
        time.sleep(3)
    # Rebuild summary from per-store json files
    summary = {
        "syncedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "appId": json.loads((ROOT / "scripts" / ".astro-app.json").read_text()).get("appId"),
        "storeCount": len(stores),
        "stores": {},
    }
    for store in stores:
        p = OUT / f"{store}.json"
        if p.exists():
            data = json.loads(p.read_text())
            summary["stores"][store] = {
                "locales": data.get("locales", []),
                "planned": data.get("keywordCount", 0),
                "added": data.get("added", 0),
            }
    (OUT / "_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"ALL STORES LOOP DONE ({len(summary['stores'])}/{len(stores)})", flush=True)


if __name__ == "__main__":
    main()
