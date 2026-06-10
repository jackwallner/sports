#!/usr/bin/env python3
"""Audit all 91 Astro stores; sync any below MIN_KW; write correct _summary.json."""
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
MIN_KW = 15
GET_TIMEOUT = 90


def app_id() -> str:
    return str(json.loads(CONFIG.read_text()).get("appId", "102"))


def planned(store: str) -> int:
    p = OUT / f"{store}.json"
    return int(json.loads(p.read_text()).get("keywordCount", 45)) if p.exists() else 45


def count_kw(store: str) -> int | None:
    for i in range(3):
        try:
            kws = call(MCP, "get_app_keywords", {"appId": app_id(), "store": store}, timeout=GET_TIMEOUT)
            return len(kws) if isinstance(kws, list) else 0
        except Exception:
            time.sleep(4 * (i + 1))
    return None


def sync_store(store: str) -> None:
    env = {**dict(__import__("os").environ), "PYTHONPATH": str(ROOT / "scripts"), "PYTHONUNBUFFERED": "1"}
    subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "astro-sync-all-stores.py"), "--store", store],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
    )


def wait_mcp(max_sec: int = 120) -> None:
    for i in range(max_sec // 5):
        if ping(MCP):
            return
        print(f"waiting for MCP... ({i+1})", flush=True)
        time.sleep(5)
    raise SystemExit("error: Astro MCP not reachable after wait")


def main() -> None:
    wait_mcp()
    stores = [s["code"] for s in json.loads(STORES_JSON.read_text())["stores"]]
    results: dict[str, dict] = {}
    for i, store in enumerate(stores):
        n = count_kw(store)
        if n is None or n < MIN_KW:
            print(f"SYNC {store}: {n}", flush=True)
            for attempt in range(3):
                sync_store(store)
                time.sleep(6)
                n = count_kw(store)
                if n is not None and n >= MIN_KW:
                    print(f"  -> {store}: {n}", flush=True)
                    results[store] = {"planned": planned(store), "count": n, "status": "synced", "added": n}
                    break
                print(f"  retry {attempt+1}/3 ({n})", flush=True)
            else:
                results[store] = {"planned": planned(store), "count": n or 0, "status": "fail", "added": 0}
                print(f"FAIL {store}: {n}", flush=True)
        else:
            print(f"OK   {store}: {n}", flush=True)
            results[store] = {"planned": planned(store), "count": n, "status": "ok", "added": 0}
        if (i + 1) % 5 == 0:
            time.sleep(2)
        else:
            time.sleep(1)
    ok = sum(1 for r in results.values() if r["count"] >= MIN_KW)
    summary = {
        "syncedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "appId": app_id(),
        "storeCount": 91,
        "verifiedOk": ok,
        "stores": dict(sorted(results.items())),
    }
    (OUT / "_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"\nDone: {ok}/91", flush=True)
    failed = [c for c, r in results.items() if r["count"] < MIN_KW]
    if failed:
        print(f"Still failing: {', '.join(failed)}", flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
