# Localization ASO — The Sideline

Backup and restore paths for App Store Connect metadata.

## Backups (this run)

| Snapshot | Path | When |
|----------|------|------|
| Pre-edit pull | `fastlane/metadata.bak.20260525-190702/` | Before ASC pull (local en-US only) |
| Pre-upload | `fastlane/metadata.bak.pre-upload-20260525-190847/` | After locale optimization, before upload |

## Restore

To revert disk metadata to a snapshot:

```bash
./scripts/restore-appstore-metadata.sh fastlane/metadata.bak.pre-upload-20260525-190847
```

To re-push restored files to ASC draft:

```bash
eval "$(python3 scripts/asc-ensure-draft-version.py | grep '^export ')"
./scripts/asc-upload-metadata.sh
SKIP_SCREENSHOTS=true ./scripts/upload-appstore-metadata.sh
```

## Draft state

- **Version:** `1.0` (`PREPARE_FOR_SUBMISSION`)
- **State file:** `scripts/.asc-state.json`
- **Locales on disk / ASC:** 50 (all deliver-supported)

## Astro

- **App:** Sports — `appId` `102` (`scripts/.astro-app.json`)
- **Stores:** 91 Apple Search Ads countries via `scripts/astro-stores-2026.json`
