# Supabase Functions

Deployable Edge Functions for the daily Sideline content pipeline.

## Suggested Schedule

Run these from Supabase schedules or any cron service that can send `x-cron-secret`.

1. `ingest-rss` around 1:00 AM local time.
2. `generate-briefings` for `{"refresh_window":"daily","personas":["cocktail_party"]}` after ingestion.
3. `generate-briefings` for Pro windows with `morning`, `midday`, and `evening` bodies if Gemini quota allows.

Example:

```bash
curl -X POST "$SUPABASE_FUNCTIONS_URL/ingest-rss" \
  -H "x-cron-secret: $CRON_SECRET"

curl -X POST "$SUPABASE_FUNCTIONS_URL/generate-briefings" \
  -H "content-type: application/json" \
  -H "x-cron-secret: $CRON_SECRET" \
  -d '{"refresh_window":"daily","personas":["cocktail_party"]}'
```

All functions emit JSON logs with `trace_id`, counts, status, and full error objects. Failed Gemini runs are saved in `generation_runs`; the app keeps reading the last successful `briefings` row.
