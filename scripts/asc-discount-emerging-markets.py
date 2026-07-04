#!/usr/bin/env python3
"""Apply the emerging-market tiered discount plan to Gist+ subscriptions and the
lifetime IAP, mirroring the Vitals plan (scripts/asc-discount-emerging-markets.py
in ~/vitals). Existing subscribers keep their price (preserveCurrentPrice). New
sign-ups after the scheduled start see the regional price.

Preview (no writes):   python3 scripts/asc-discount-emerging-markets.py
Apply:                 python3 scripts/asc-discount-emerging-markets.py --apply
"""
from __future__ import annotations
import sys, time, json, urllib.request, urllib.error
from datetime import date, timedelta
sys.path.insert(0, "scripts")
from asc_lib import load_credentials, bearer_token

APP = "6770138156"
SUB_MONTHLY = "6773584509"   # Gist+ Monthly, USA $2.99
SUB_YEARLY  = "6773584046"   # Gist+ Yearly,  USA $19.99
IAP_LIFETIME = "6773583847"  # Gist+ Lifetime, USA $39.99 (non-consumable)

# Target USD-equivalent ceilings per tier: (yearly, monthly, lifetime)
TIERS = {
    # Severe-gap markets (~60-67% off)
    "IND": (7.99, 0.99, 14.99), "PAK": (7.99, 0.99, 14.99), "BGD": (7.99, 0.99, 14.99),
    "IDN": (7.99, 0.99, 14.99), "VNM": (7.99, 0.99, 14.99), "PHL": (7.99, 0.99, 14.99),
    "EGY": (7.99, 0.99, 14.99), "NGA": (7.99, 0.99, 14.99),
    # Moderate-gap markets (~40% off)
    "TUR": (11.99, 1.49, 21.99), "BRA": (11.99, 1.49, 21.99), "MEX": (11.99, 1.49, 21.99),
    "COL": (11.99, 1.49, 21.99), "CHL": (11.99, 1.49, 21.99), "THA": (11.99, 1.49, 21.99),
    "MYS": (11.99, 1.49, 21.99), "POL": (11.99, 1.49, 21.99), "HUN": (11.99, 1.49, 21.99),
    "ROU": (11.99, 1.49, 21.99), "ZAF": (11.99, 1.49, 21.99), "RUS": (11.99, 1.49, 21.99),
    # Light-gap markets (~25% off)
    "SAU": (14.99, 1.99, 29.99), "ARE": (14.99, 1.99, 29.99),
    "CZE": (14.99, 1.99, 29.99), "CHN": (14.99, 1.99, 29.99),
}

FX = {  # USD per 1 unit local currency (approx, for ranking only)
    "INR":0.012,"PKR":0.0036,"BDT":0.0082,"IDR":0.000062,"VND":0.0000395,
    "PHP":0.0173,"EGP":0.020,"NGN":0.00065,
    "TRY":0.029,"BRL":0.20,"MXN":0.049,"COP":0.00024,"CLP":0.0011,
    "THB":0.029,"MYR":0.22,"PLN":0.25,"HUF":0.0028,"RON":0.22,"ZAR":0.055,"RUB":0.011,
    "SAR":0.27,"AED":0.27,"CZK":0.044,"CNY":0.14,"USD":1.0,
}
TERRITORY_CURRENCY = {
    "IND":"INR","PAK":"PKR","BGD":"BDT","IDN":"IDR","VNM":"VND","PHL":"PHP",
    "EGY":"EGP","NGA":"NGN","TUR":"TRY","BRA":"BRL","MEX":"MXN","COL":"COP",
    "CHL":"CLP","THA":"THB","MYS":"MYR","POL":"PLN","HUN":"HUF","ROU":"RON",
    "ZAF":"ZAR","RUS":"RUB","SAU":"SAR","ARE":"AED","CZE":"CZK","CHN":"CNY",
}

BASE = "https://api.appstoreconnect.apple.com"
TOKEN = bearer_token(*load_credentials())
SCHEDULED_START = (date.today() + timedelta(days=2)).isoformat()

def call(method, path, body=None):
    req = urllib.request.Request(BASE + path,
        data=json.dumps(body).encode() if body is not None else None, method=method,
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read().decode(); return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")

def get_all(path):
    out=[];
    while path:
        s,o = call("GET", path)
        if s>=400: raise RuntimeError(f"GET {path} -> {s}: {o}")
        out += o.get("data",[])
        nxt = (o.get("links") or {}).get("next")
        path = nxt[len(BASE):] if nxt else None
    return out

def pick(points, terr, target_usd):
    ccy = TERRITORY_CURRENCY.get(terr,"USD"); fx = FX.get(ccy,1.0)
    pts = sorted((float(p["attributes"]["customerPrice"])*fx, float(p["attributes"]["customerPrice"]), p["id"]) for p in points)
    elig = [x for x in pts if x[0] <= target_usd]
    return (elig[-1] if elig else pts[0])

def do_subs(apply):
    for sub_id, label, idx in ((SUB_YEARLY,"Yearly",0),(SUB_MONTHLY,"Monthly",1)):
        print(f"\n=== {label} ({sub_id}) ===")
        for terr,(ty,tm,tl) in TIERS.items():
            target = (ty,tm)[idx]
            pts = get_all(f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]={terr}&limit=200")
            if not pts:
                print(f"  {terr}: SKIP (no price points — territory not available for paid content)")
                continue
            usd_eq, cp, pp_id = pick(pts, terr, target)
            print(f"  {terr}: {cp} {TERRITORY_CURRENCY.get(terr)} (~${usd_eq:.2f}, target<=${target})", end="")
            if apply:
                body={"data":{"type":"subscriptionPrices","attributes":{"preserveCurrentPrice":True,"startDate":SCHEDULED_START},
                    "relationships":{"subscription":{"data":{"type":"subscriptions","id":sub_id}},
                        "territory":{"data":{"type":"territories","id":terr}},
                        "subscriptionPricePoint":{"data":{"type":"subscriptionPricePoints","id":pp_id}}}}}
                s,o=call("POST","/v1/subscriptionPrices",body)
                print("  -> "+("ok" if s in (200,201) else f"FAIL {s} {json.dumps(o.get('errors',o))[:160]}"))
                time.sleep(0.15)
            else:
                print("  [preview]")

def do_lifetime(apply):
    print(f"\n=== Lifetime IAP ({IAP_LIFETIME}) ===")
    # base USA point ($39.99) + discounted territory points, one schedule
    usa = get_all(f"/v2/inAppPurchases/{IAP_LIFETIME}/pricePoints?filter[territory]=USA&limit=400")
    usa_pp = [p for p in usa if p["attributes"].get("customerPrice")=="39.99"]
    usa_pp = usa_pp[0]["id"] if usa_pp else sorted(usa,key=lambda p:abs(float(p["attributes"]["customerPrice"])-39.99))[0]["id"]
    included=[{"type":"inAppPurchasePrices","id":"${usa}","attributes":{"startDate":None},
        "relationships":{"inAppPurchasePricePoint":{"data":{"type":"inAppPurchasePricePoints","id":usa_pp}}}}]
    manual=[{"type":"inAppPurchasePrices","id":"${usa}"}]
    for terr,(ty,tm,tl) in TIERS.items():
        pts = get_all(f"/v2/inAppPurchases/{IAP_LIFETIME}/pricePoints?filter[territory]={terr}&limit=400")
        if not pts:
            print(f"  {terr}: SKIP (no price points)")
            continue
        usd_eq, cp, pp_id = pick(pts, terr, tl)
        tid=f"${{t_{terr}}}"
        print(f"  {terr}: {cp} {TERRITORY_CURRENCY.get(terr)} (~${usd_eq:.2f}, target<=${tl})")
        included.append({"type":"inAppPurchasePrices","id":tid,"attributes":{"startDate":None},
            "relationships":{"territory":{"data":{"type":"territories","id":terr}},
                "inAppPurchasePricePoint":{"data":{"type":"inAppPurchasePricePoints","id":pp_id}}}})
        manual.append({"type":"inAppPurchasePrices","id":tid})
    if apply:
        body={"data":{"type":"inAppPurchasePriceSchedules",
            "relationships":{"inAppPurchase":{"data":{"type":"inAppPurchases","id":IAP_LIFETIME}},
                "baseTerritory":{"data":{"type":"territories","id":"USA"}},
                "manualPrices":{"data":manual}}},"included":included}
        s,o=call("POST","/v1/inAppPurchasePriceSchedules",body)
        print("  schedule -> "+("ok" if s in (200,201) else f"FAIL {s} {json.dumps(o.get('errors',o))[:300]}"))
    else:
        print("  [preview] would set 24-territory lifetime schedule (base USA $39.99 preserved)")

def main():
    apply = "--apply" in sys.argv
    print(f"Gist regional pricing {'APPLY' if apply else 'PREVIEW'} | start {SCHEDULED_START} | {len(TIERS)} territories")
    do_subs(apply)
    do_lifetime(apply)
    print("\nDone.")

if __name__ == "__main__":
    main()
