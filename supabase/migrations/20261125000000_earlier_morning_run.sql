-- Move the morning run from 14:05 UTC (6:05 AM PST) to 12:05 UTC (4:05 AM PST)
-- and retry any missing room in Postgres before people wake up.
--
-- Gemini's free tier returns 503 "high demand" when Google is busy, and the
-- US morning is the busiest time: it failed every persona on 2026-11-23, 24 and
-- 25 at 6:10 AM PT. Running two hours earlier dodges the peak, and the retries
-- below get a missing room back by about 6 AM PT instead of 7:30.
--
-- generate-briefings derives the window from the UTC hour (<16 is morning), so
-- 12 and 13 UTC are still the morning window. cron.schedule with an existing
-- job name replaces that job's schedule.
select cron.schedule('sideline-ingest', '5 12,19,23 * * *', $$select public.sideline_invoke('ingest-rss')$$);
select cron.schedule('sideline-cocktail-party', '10 12,19,23 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["cocktail_party"]}')$$);
select cron.schedule('sideline-office-watercooler', '14 12,19,23 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["office_watercooler"]}')$$);
select cron.schedule('sideline-date-night', '18 12,19,23 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["date_night"]}')$$);
select cron.schedule('sideline-sports-talk-for-moms', '22 12,19,23 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["sports_talk_for_moms"]}')$$);

-- Morning retries, every 10 minutes from 4:30 to 5:50 AM PST. With missing_only
-- each call regenerates at most one persona that has no briefing in the last
-- three hours, and returns "all_fresh" in well under a second otherwise. Ten
-- minutes apart keeps calls from overlapping (one takes up to about 2.5 minutes).
select cron.schedule('sideline-morning-retry', '30,40,50 12 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["cocktail_party","office_watercooler","date_night","sports_talk_for_moms"],"missing_only":true}')$$);
select cron.schedule('sideline-morning-retry-2', '0,10,20,30,40,50 13 * * *',
  $$select public.sideline_invoke('generate-briefings', '{"personas":["cocktail_party","office_watercooler","date_night","sports_talk_for_moms"],"missing_only":true}')$$);
