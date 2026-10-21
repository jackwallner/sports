# Gist on Google Play: release preparation

State on 2026-10-20, from the Android port in `android/`. Every answer below
comes from the code and its network traffic, not from assumptions. Re-check it
if `android/` changes.

## Build facts

| Field | Value |
|---|---|
| Package | `com.jackwallner.sports` |
| versionName / versionCode | 1.1.4 / 1 |
| minSdk / targetSdk / compileSdk | 26 / 36 / 36 |
| Permissions | `INTERNET` only |
| Billing | RevenueCat 10.23.2 (Google Play Billing), entitlement `Sports Pro` |
| Review | Play In-App Review 2.0.2, no question in front of it |
| Native libraries | none of our own; check SDK `.so` files for 16 KB alignment when the AAB is built |

## Listing copy

In `android/play-assets/listing/`: `title.txt` (23 of 30 characters),
`short-description.txt` (70 of 80), `full-description.txt` (about 1,600 of
4,000), `release-notes.txt`. No prices, no em dashes, no league or team claims.
Icon: `android/play-assets/icon-512.png` (512 x 512, no alpha).

Store graphics (done 2026-10-21, see `android/play-assets/README.md`):
`feature-graphic.png` (1024 x 500, from `feature-graphic.svg`), four 1080 x 1920
screenshots in `screenshots/` composited from `safeScreenshot` debug captures
with status bar demo mode, and fastlane-layout copy in `metadata/android/en-US/`.
Raw 1080 x 2400 captures exceed Play's 2:1 limit, so they are composited, not
uploaded raw. The fixture's lead card and second story card get Pollinations
art with garbled lettering, so the set avoids them; recheck every card's art
before recapturing. Live-feed captures name real people, so keep them out of
the listing.

## Data Safety answers

| Question | Answer | Why |
|---|---|---|
| Collects or shares user data | Yes, collected | RevenueCat receives purchase and app-activity data |
| Encrypted in transit | Yes | All traffic is HTTPS (Supabase, RevenueCat, Pollinations, Play) |
| Users can request deletion | Yes, by email (jack@jackwallner.com) | No account exists, so there is nothing to delete in-app |
| Financial info > Purchase history | Collected, not shared. App functionality | RevenueCat verifies the Play purchase to unlock Pro |
| App activity > Other actions | Collected, not shared. Analytics | Upgrade-screen counts, timing and the converting screen, as RevenueCat subscriber attributes (`ConversionDiagnostics`) |
| Device or other IDs | Collected, not shared. App functionality | RevenueCat anonymous app user ID |
| Location, personal info, contacts, messages, photos, health, files, calendar, web history | Not collected | The app never reads them |

Supabase and Pollinations requests carry no user data (Supabase gets the room
name; Pollinations gets a scene description and seed). Like any HTTPS
request they see the device's IP address, which the app does not send as data
or keep; Play's ephemeral-processing exemption covers that. Service providers
are not "sharing" under Play's definitions. The privacy policy (`docs/privacy-policy.html`) was updated on
2026-10-20 to name Google Play and Pollinations and the upgrade statistics.

## Other App content forms

- **Privacy policy:** https://jackwallner.github.io/sports/privacy-policy.html
- **Ads:** No ads.
- **App access:** All features need no login. Pro rooms are behind a purchase.
  Give reviewers the code whose SHA-256 is `PLAY_REVIEW_CODE_SHA256`, with:
  "Open Settings, long-press Version, enter the code, tap Unlock."
- **Target audience:** 18 and over (the privacy policy says the app is not
  directed at children under 13; 18+ keeps it out of Families review).
- **Content rating (IARC):** reference/news-style content. No violence, sex,
  profanity, drugs, gambling or user-to-user interaction. Briefings never
  give betting angles (`AGENTS.md` rule).
- **Generative AI:** briefings (Gemini) and card art (Pollinations) are
  generated server-side. Users can report any card in the app: long-press a
  card, then "Report this card" opens a mail draft quoting it. Settings also
  has Send Feedback.
- **Government, financial, health features:** none.

## Decision needed from Jack

- **Category: Sports or News & Magazines.** Gist summarises sports news, but
  its purpose is conversation prep. Recommended: **Sports**. Choosing News &
  Magazines triggers Play's News apps declaration (publisher contact details,
  source transparency) and stricter review.

## Products (create in Play Console before RevenueCat)

Use the iOS product IDs, read from App Store Connect on the Air (they are not
in this repo). For each subscription: one Play subscription with the iOS
product ID, base plans `monthly` and `yearly`, and a 7-day free-trial offer for
new customers on both (Jack keeps monthly trials). Add the lifetime in-app
product with its iOS ID. Price from the live ASC prices and PPP ladder: the
repo's App Store description still says $5.99/$29.99, but the 2026-06-29
pricing pass cut subscriptions to $2.99/$19.99, so read ASC first. Review
Play's converted local prices against the iOS ladder before activating.

Then in RevenueCat project `56682a14`: add the Play app for
`com.jackwallner.sports`, attach the service account, import the Play
products, attach them to the existing `Sports Pro` entitlement and the
`default` offering's `$rc_monthly`, `$rc_annual` and `$rc_lifetime` packages.
Do not change the iOS products, entitlement or offering. Register the Play app
with rc-clean (`~/.rc-clean/apps.json` on the Air, copied to the MBP), with
`"ios": {"filter_platform": "iOS"}` because Android shares the iOS project.

## Remaining Console steps, in order

1. Confirm whether a Play app record exists for `com.jackwallner.sports`;
   create it (app name "Gist: Sports Small Talk", free, app) only if not.
2. Air release worker: build and verify the signed AAB (`bundleRelease`):
   application ID, targetSdk 36, versionCode, upload certificate, permissions
   (`INTERNET`, plus the billing and review permissions the SDKs merge), 16 KB
   alignment.
3. Upload to internal testing; add the license testers.
4. Create and activate the products above; wire RevenueCat; rc-clean.
5. Fill store listing, feature graphic, screenshots, and every App content
   form above, including the reviewer code under App access.
6. License-tester purchase and restore on a Play Store image; confirm the
   entitlement in RevenueCat.
7. Read the pre-launch report and fix anything it flags.
8. Production submission follows the fleet pacing rule (one new app at a
   time on the account, after the previous review finishes). Managed
   publishing stays off.
