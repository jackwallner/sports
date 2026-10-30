-- Store briefing timestamps in whole seconds. PostgREST prints a fractional
-- part whenever it is not zero, and JSONDecoder's .iso8601 rejects that before
-- iOS 26, so iOS 17 and 18 builds could not decode any live briefing.
alter table public.briefings
  alter column generated_at type timestamptz(0),
  alter column expires_at type timestamptz(0);
