-- Supabase grants TRUNCATE to anon and authenticated on every new table. RLS
-- does not cover TRUNCATE and PostgREST cannot call it, but the grant has no
-- use. service_role keeps full access.

revoke truncate on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke truncate on tables from anon, authenticated;
