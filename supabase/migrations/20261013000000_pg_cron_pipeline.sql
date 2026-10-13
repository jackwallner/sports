-- Schedule the content pipeline inside Postgres instead of GitHub Actions.
-- GitHub's scheduler ran these jobs 3 to 4 hours late and then skipped a whole
-- day (2026-10-12), leaving every room stale. pg_cron fires on the minute.
--
-- The functions URL and cron secret live in Vault, never in this file:
--   select vault.create_secret('<https://<ref>.supabase.co/functions/v1>', 'sideline_functions_url');
--   select vault.create_secret('<CRON_SECRET>', 'sideline_cron_secret');

create extension if not exists pg_cron;
create extension if not exists pg_net;

create or replace function public.sideline_invoke(fn text, body jsonb default '{}'::jsonb)
returns bigint
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  base_url text := (select decrypted_secret from vault.decrypted_secrets where name = 'sideline_functions_url');
  secret text := (select decrypted_secret from vault.decrypted_secrets where name = 'sideline_cron_secret');
begin
  if base_url is null or secret is null then
    raise exception 'sideline_functions_url / sideline_cron_secret missing from vault';
  end if;
  -- Generation takes about a minute per persona; the default 5s timeout would
  -- drop the connection mid-run.
  return net.http_post(
    url := base_url || '/' || fn,
    headers := jsonb_build_object('content-type', 'application/json', 'x-cron-secret', secret),
    body := body,
    timeout_milliseconds := 300000
  );
end;
$$;

revoke all on function public.sideline_invoke(text, jsonb) from public, anon, authenticated;

-- Windows are derived from the UTC hour by generate-briefings
-- (<16 morning, <22 midday, otherwise evening). Personas run a few minutes
-- apart so Gemini calls never overlap and each finishes before the next.
select cron.schedule('sideline-ingest', '5 14,19,23 * * *', $$select public.sideline_invoke('ingest-rss')$$);
select cron.schedule('sideline-cocktail-party', '10 14,19,23 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["cocktail_party"]}')$$);
select cron.schedule('sideline-office-watercooler', '14 14,19,23 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["office_watercooler"]}')$$);
select cron.schedule('sideline-date-night', '18 14,19,23 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["date_night"]}')$$);
select cron.schedule('sideline-sports-talk-for-moms', '22 14,19,23 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["sports_talk_for_moms"]}')$$);
