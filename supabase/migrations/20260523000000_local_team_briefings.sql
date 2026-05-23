-- Local team briefings: tag scope=local rows with the team they cover.
alter table public.briefings add column if not exists team text;
alter table public.generation_runs add column if not exists team text;

-- Latest-per-team lookups for scope=local (iOS queries persona+scope+team).
create index if not exists briefings_local_latest_idx
  on public.briefings (persona, scope, team, generated_at desc);
