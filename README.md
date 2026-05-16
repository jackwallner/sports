# The Sideline

Conversation fuel for people who do not follow sports but still need to talk to people who do.

This repository contains the native SwiftUI app scaffold plus the Supabase content pipeline that generates cached, source-cited daily briefings.

## Shape

- `Sideline/` - SwiftUI app views and app wiring.
- `Shared/` - DTOs, services, caching, entitlement abstractions shared by the app and tests.
- `SupabaseFunctions/` - Edge Functions for RSS ingestion, Gemini generation, and briefing fetches.
- `supabase/migrations/` - Postgres schema and seed feeds.
- `Tests/` - focused smoke tests for the shared briefing contract.

The app never calls Gemini directly. Scheduled backend jobs pull curated RSS feeds, generate strict JSON briefings with Gemini, validate them, and save them to Supabase. The app fetches the latest cached briefing and falls back to SwiftData cache when offline.

## Required Environment

Backend functions:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`
- `CRON_SECRET`
- `GEMINI_MODEL` optional, defaults to `gemini-1.5-flash`
- `GEMINI_MIN_INTERVAL_MS` optional, defaults to `4500`

iOS app:

- `SIDELINE_SUPABASE_URL`
- `SIDELINE_SUPABASE_ANON_KEY`

If the app config is missing, it uses bundled sample content so the UI can still be exercised locally.
