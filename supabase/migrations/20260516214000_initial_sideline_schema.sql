create extension if not exists pgcrypto;

create type public.persona as enum (
  'cocktail_party',
  'sports_talk_for_moms',
  'office_watercooler',
  'date_night',
  'local_team'
);

create type public.briefing_scope as enum (
  'national',
  'local'
);

create type public.refresh_window as enum (
  'daily',
  'morning',
  'midday',
  'evening'
);

create type public.generation_status as enum (
  'pending',
  'running',
  'succeeded',
  'failed',
  'skipped'
);

create table public.source_feeds (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  url text not null unique,
  source_name text not null,
  categories text[] not null default '{}',
  trust_weight integer not null default 50 check (trust_weight between 0 and 100),
  is_active boolean not null default true,
  last_fetched_at timestamptz,
  last_error jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.source_items (
  id uuid primary key default gen_random_uuid(),
  feed_id uuid references public.source_feeds(id) on delete set null,
  source_name text not null,
  source_url text not null,
  url_hash text not null unique,
  headline text not null,
  summary text,
  author text,
  published_at timestamptz,
  fetched_at timestamptz not null default now(),
  categories text[] not null default '{}',
  raw_item jsonb not null default '{}'::jsonb,
  dedupe_key text,
  is_pop_culture boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.story_clusters (
  id uuid primary key default gen_random_uuid(),
  cluster_key text not null unique,
  representative_headline text not null,
  categories text[] not null default '{}',
  source_count integer not null default 0,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  score numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.story_cluster_items (
  cluster_id uuid not null references public.story_clusters(id) on delete cascade,
  source_item_id uuid not null references public.source_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (cluster_id, source_item_id)
);

create table public.generation_runs (
  id uuid primary key default gen_random_uuid(),
  trace_id text not null,
  persona public.persona not null,
  scope public.briefing_scope not null,
  refresh_window public.refresh_window not null,
  status public.generation_status not null default 'pending',
  model text,
  prompt_version text not null,
  input_count integer not null default 0,
  source_item_ids uuid[] not null default '{}',
  started_at timestamptz,
  finished_at timestamptz,
  request_payload jsonb,
  response_payload jsonb,
  error jsonb,
  retry_count integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.briefings (
  id uuid primary key default gen_random_uuid(),
  persona public.persona not null,
  scope public.briefing_scope not null,
  refresh_window public.refresh_window not null,
  headline text not null,
  tl_dr text not null,
  bullets jsonb not null,
  suggested_question text not null,
  source_count integer not null,
  generated_at timestamptz not null default now(),
  expires_at timestamptz,
  model text,
  prompt_version text not null,
  run_id uuid references public.generation_runs(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint briefings_bullets_is_array check (jsonb_typeof(bullets) = 'array')
);

create index source_items_published_idx on public.source_items (published_at desc nulls last);
create index source_items_categories_idx on public.source_items using gin (categories);
create index story_clusters_score_idx on public.story_clusters (score desc, last_seen_at desc);
create index generation_runs_trace_idx on public.generation_runs (trace_id);
create index briefings_latest_idx on public.briefings (persona, scope, generated_at desc);

alter table public.source_feeds enable row level security;
alter table public.source_items enable row level security;
alter table public.story_clusters enable row level security;
alter table public.story_cluster_items enable row level security;
alter table public.generation_runs enable row level security;
alter table public.briefings enable row level security;

create policy "Anyone can read generated briefings"
on public.briefings
for select
to anon, authenticated
using (true);

insert into public.source_feeds (name, url, source_name, categories, trust_weight) values
  ('ESPN Top Headlines', 'https://www.espn.com/espn/rss/news', 'ESPN', array['national', 'sports'], 80),
  ('ESPN NFL', 'https://www.espn.com/espn/rss/nfl/news', 'ESPN', array['nfl', 'national'], 75),
  ('ESPN NBA', 'https://www.espn.com/espn/rss/nba/news', 'ESPN', array['nba', 'national'], 75),
  ('ESPN MLB', 'https://www.espn.com/espn/rss/mlb/news', 'ESPN', array['mlb', 'national'], 70),
  ('ESPN NHL', 'https://www.espn.com/espn/rss/nhl/news', 'ESPN', array['nhl', 'national'], 65),
  ('Yahoo Sports', 'https://sports.yahoo.com/rss/', 'Yahoo Sports', array['national', 'pop_culture'], 70),
  ('CBS Sports Headlines', 'https://www.cbssports.com/rss/headlines/', 'CBS Sports', array['national', 'sports'], 65),
  ('AP Sports', 'https://apnews.com/hub/sports?output=rss', 'AP', array['national', 'sports'], 75)
on conflict (url) do nothing;
