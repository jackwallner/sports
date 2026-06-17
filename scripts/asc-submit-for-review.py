#!/usr/bin/env python3
"""Attach the latest valid build to the editable App Store version and submit
it for review via the modern reviewSubmissions flow.

Usage:
    set -a; . ~/.baseball_credentials; set +a
    python3 asc-submit-for-review.py [--build N] [--dry-run]

Without --build it picks the highest-numbered VALID, non-expired build.
"""
from __future__ import annotations

import argparse
import sys

import asc_lib as a

APP_ID = "6770138156"
PLATFORM = "IOS"


def latest_valid_build(c, prefer: int | None):
    builds = c.get(f"/builds?filter[app]={APP_ID}&limit=20").get("data", [])
    cand = []
    for b in builds:
        at = b["attributes"]
        if at.get("processingState") == "VALID" and not at.get("expired"):
            cand.append((int(at["version"]), b["id"], at["version"]))
    if not cand:
        sys.exit("error: no VALID non-expired builds")
    if prefer is not None:
        for v, bid, vs in cand:
            if v == prefer:
                return bid, vs
        sys.exit(f"error: build {prefer} is not VALID/available")
    cand.sort(reverse=True)
    return cand[0][1], cand[0][2]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", type=int, default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    c = a.ASCClient(a.bearer_token(*a.load_credentials()))

    version = a.find_editable_version(c, APP_ID)
    if version is None:
        sys.exit("error: no editable App Store version found")
    vid = version["id"]
    vstate = version["attributes"].get("appStoreState")
    vstr = version["attributes"].get("versionString")
    print(f"editable version {vstr} state={vstate} id={vid}")

    build_id, build_no = latest_valid_build(c, args.build)
    print(f"selected build {build_no} id={build_id}")

    if args.dry_run:
        print("dry-run: stopping before any mutation")
        return

    # 1. Attach build to the version.
    c.request(
        "PATCH",
        f"/appStoreVersions/{vid}/relationships/build",
        {"data": {"type": "builds", "id": build_id}},
    )
    print(f"attached build {build_no} to version {vstr}")

    # 2. Cancel any open/rejected submission that would block a new one.
    for rs in c.get(f"/reviewSubmissions?filter[app]={APP_ID}&limit=20").get("data", []):
        st = rs["attributes"].get("state")
        if st in ("UNRESOLVED_ISSUES", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW"):
            c.patch(
                f"/reviewSubmissions/{rs['id']}",
                {"data": {"type": "reviewSubmissions", "id": rs["id"], "attributes": {"canceled": True}}},
            )
            print(f"canceled prior submission {rs['id']} (was {st})")

    # 3. Create a fresh review submission.
    rs = c.post(
        "/reviewSubmissions",
        {"data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": PLATFORM},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }},
    )["data"]
    rs_id = rs["id"]
    print(f"created review submission {rs_id}")

    # 4. Add the version as an item.
    c.post(
        "/reviewSubmissionItems",
        {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": rs_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}},
            },
        }},
    )
    print("added version to submission")

    # 5. Submit.
    out = c.patch(
        f"/reviewSubmissions/{rs_id}",
        {"data": {"type": "reviewSubmissions", "id": rs_id, "attributes": {"submitted": True}}},
    )
    print("submitted. state:", out["data"]["attributes"].get("state"))


if __name__ == "__main__":
    main()
