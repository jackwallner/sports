#!/usr/bin/env python3
"""Audit Gist+ regional pricing and keep the lifetime IAP in sync with the
already-configured subscription discount structure.

IMPORTANT — read before running any pricing change on this app:
Gist ALREADY ships a deliberate emerging-market discount on the monthly/yearly
subscriptions (deeper than a flat "vitals"-style ceiling plan: India ~$6, Nigeria
~$5, Indonesia ~$5.5 on the yearly, ratios 0.23-0.88 of the equalized US price).
A naive "set the highest price point <= a USD ceiling" pass RAISES those prices,
because the existing prices are already below any sane ceiling. Do not do that.

This tool instead:
  1. AUDITS: prints every territory whose yearly sub is discounted vs the US-
     equalized price, with the discount ratio.
  2. SYNCS LIFETIME: rebuilds the lifetime (non-consumable) price schedule so each
     discounted territory gets the same discount ratio it has on the yearly sub,
     off that territory's equalized $39.99 price. Subscription prices are never
     touched. Territories with no discount derive from the US base automatically.

Audit only:   python3 scripts/asc-discount-emerging-markets.py
Sync lifetime: python3 scripts/asc-discount-emerging-markets.py --apply
"""
from __future__ import annotations
import sys, json, base64, urllib.request, urllib.error
sys.path.insert(0, "scripts")
from asc_lib import load_credentials, bearer_token

SUB_YEARLY  = "6773584046"
SUB_MONTHLY = "6773584509"
IAP_LIFETIME = "6773583847"
BASE = "https://api.appstoreconnect.apple.com"
TOKEN = bearer_token(*load_credentials())

def call(method, path, body=None):
    req = urllib.request.Request(BASE + path,
        data=json.dumps(body).encode() if body is not None else None, method=method,
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            raw = r.read().decode(); return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")

def pages(path):
    rows, inc = [], []
    while path:
        s, o = call("GET", path)
        if s >= 400: raise RuntimeError(f"{path} -> {s}: {o}")
        rows += o["data"]; inc += o.get("included", [])
        nxt = (o.get("links") or {}).get("next"); path = nxt[len(BASE):] if nxt else None
    return rows, inc

def _dec(ppid): return json.loads(base64.b64decode(ppid + "=" * (-len(ppid) % 4)))
def terr_of(ppid): return _dec(ppid).get("t")
def tier_of(ppid): return _dec(ppid).get("p")

def yearly_ratios():
    """territory -> (current_local, full_local, ratio) for discounted territories."""
    s, o = call("GET", f"/v1/subscriptions/{SUB_YEARLY}/prices?filter[territory]=USA&include=subscriptionPricePoint")
    usa = o["data"][0]["relationships"]["subscriptionPricePoint"]["data"]["id"]
    eq, _ = pages(f"/v1/subscriptionPricePoints/{usa}/equalizations?limit=200")
    full = {terr_of(d["id"]): float(d["attributes"]["customerPrice"]) for d in eq}
    rows, inc = pages(f"/v1/subscriptions/{SUB_YEARLY}/prices?include=subscriptionPricePoint&limit=200")
    price = {i["id"]: float(i["attributes"]["customerPrice"]) for i in inc if i["type"] == "subscriptionPricePoints"}
    out = {}
    for d in rows:
        if d["attributes"].get("startDate") is None:
            pp = d["relationships"]["subscriptionPricePoint"]["data"]["id"]
            t = terr_of(pp); c = price.get(pp); f = full.get(t)
            if c and f and c < f * 0.98:
                out[t] = (c, f, c / f)
    return out

def sync_lifetime(ratios, apply):
    lp, _ = pages(f"/v2/inAppPurchases/{IAP_LIFETIME}/pricePoints?filter[territory]=USA&limit=400")
    usa = [p for p in lp if p["attributes"].get("customerPrice") == "39.99"] or \
          [min(lp, key=lambda p: abs(float(p["attributes"]["customerPrice"]) - 39.99))]
    usa_id = usa[0]["id"]; usa_tier = tier_of(usa_id)
    included = [{"type": "inAppPurchasePrices", "id": "${usa}", "attributes": {"startDate": None},
                "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": usa_id}}}}]
    manual = [{"type": "inAppPurchasePrices", "id": "${usa}"}]
    print("\nLifetime sync (ratio-matched to yearly):")
    for t, r in sorted(ratios.items()):
        pts, _ = pages(f"/v2/inAppPurchases/{IAP_LIFETIME}/pricePoints?filter[territory]={t}&limit=400")
        by_tier = {tier_of(p["id"]): float(p["attributes"]["customerPrice"]) for p in pts}
        full = by_tier.get(usa_tier)
        if not full:
            print(f"  {t}: no full-tier lifetime point, skip"); continue
        target = r * full
        cand = sorted((float(p["attributes"]["customerPrice"]), p["id"]) for p in pts)
        elig = [x for x in cand if x[0] <= target] or [cand[0]]
        price, ppid = elig[-1]
        print(f"  {t}: {price} (full {full}, ratio {r:.3f})")
        tid = f"${{t_{t}}}"
        included.append({"type": "inAppPurchasePrices", "id": tid, "attributes": {"startDate": None},
            "relationships": {"territory": {"data": {"type": "territories", "id": t}},
                "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": ppid}}}})
        manual.append({"type": "inAppPurchasePrices", "id": tid})
    if apply:
        body = {"data": {"type": "inAppPurchasePriceSchedules",
            "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": IAP_LIFETIME}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": manual}}}, "included": included}
        s, o = call("POST", "/v1/inAppPurchasePriceSchedules", body)
        print("schedule ->", "ok" if s in (200, 201) else f"FAIL {s} {json.dumps(o.get('errors', o))[:300]}")
    else:
        print(f"[audit] would sync lifetime for {len(manual)-1} territories (run with --apply)")

def main():
    apply = "--apply" in sys.argv
    ratios = yearly_ratios()
    print(f"Discounted territories on yearly sub: {len(ratios)}")
    for t in sorted(ratios, key=lambda x: ratios[x][2]):
        c, f, r = ratios[t]; print(f"  {t}: {c} / full {f}  = {r:.3f}")
    sync_lifetime(ratios, apply)

if __name__ == "__main__":
    main()
