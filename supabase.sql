-- Run once in Supabase SQL Editor. RLS allows the public page to INSERT only;
-- read access remains dashboard-only.
create table if not exists public.event_events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  event_slug text not null,
  session_id uuid not null,
  event_name text not null,
  path text,
  referrer text,
  properties jsonb not null default '{}'::jsonb
);
create index if not exists event_events_event_name_created_at_idx on public.event_events (event_slug, event_name, created_at desc);
create index if not exists event_events_session_idx on public.event_events (event_slug, session_id);

create table if not exists public.event_registrations (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  event_slug text not null,
  session_id uuid not null,
  name text not null check (char_length(name) between 1 and 30),
  contact text not null check (char_length(contact) between 3 and 80),
  quantity smallint not null default 1 check (quantity between 1 and 2)
);
create unique index if not exists event_registrations_event_session_key on public.event_registrations (event_slug, session_id);

alter table public.event_events enable row level security;
alter table public.event_registrations enable row level security;

drop policy if exists "public can write event metrics" on public.event_events;
create policy "public can write event metrics" on public.event_events for insert to anon with check (true);

drop policy if exists "public can submit a registration" on public.event_registrations;
create policy "public can submit a registration" on public.event_registrations for insert to anon with check (true);

-- The browser can write only. Raw events and registrations remain dashboard-only.
revoke all on public.event_events, public.event_registrations from anon, authenticated;
grant insert on public.event_events, public.event_registrations to anon;
grant usage, select on sequence public.event_events_id_seq, public.event_registrations_id_seq to anon;

-- Paste these into the Supabase SQL editor when you want a lightweight dashboard.
create or replace view public.event_funnel as
with per_session as (
  select event_slug, session_id,
    bool_or(event_name = 'page_view') as visited,
    bool_or(event_name in ('hero_apply', 'nav_apply', 'apply_open')) as cta_clicked,
    bool_or(event_name = 'application_started') as started,
    bool_or(event_name = 'purchase_completed') as completed
  from public.event_events group by event_slug, session_id
)
select event_slug,
  count(*) filter (where visited) as visitors,
  count(*) filter (where cta_clicked) as cta_clickers,
  count(*) filter (where started) as application_starters,
  count(*) filter (where completed) as conversions,
  round(100.0 * count(*) filter (where completed) / nullif(count(*) filter (where visited), 0), 2) as conversion_rate_percent,
  round(100.0 * (count(*) filter (where visited) - count(*) filter (where cta_clicked)) / nullif(count(*) filter (where visited), 0), 2) as landing_dropoff_percent,
  round(100.0 * (count(*) filter (where cta_clicked) - count(*) filter (where started)) / nullif(count(*) filter (where cta_clicked), 0), 2) as cta_dropoff_percent,
  round(100.0 * (count(*) filter (where started) - count(*) filter (where completed)) / nullif(count(*) filter (where started), 0), 2) as form_dropoff_percent
from per_session group by event_slug;

-- Button/interaction leaderboard for growth experiments.
create or replace view public.event_button_clicks as
select event_slug, event_name,
  coalesce(properties ->> 'label', event_name) as label,
  count(*) as clicks,
  count(distinct session_id) as unique_clickers
from public.event_events
where event_name in ('nav_logo', 'nav_apply', 'hero_apply', 'hero_program', 'apply_open',
  'program_costume', 'program_booth', 'program_stage')
group by event_slug, event_name, coalesce(properties ->> 'label', event_name);

-- Read-only aggregate endpoints for dashboard.html. No raw events or PII are returned.
create or replace function public.get_event_funnel(p_event_slug text default 'pnu-halloween-2026')
returns setof public.event_funnel
language sql stable security definer set search_path = public
as $$
  select * from public.event_funnel where event_slug = p_event_slug;
$$;

create or replace function public.get_event_button_clicks(p_event_slug text default 'pnu-halloween-2026')
returns setof public.event_button_clicks
language sql stable security definer set search_path = public
as $$
  select * from public.event_button_clicks where event_slug = p_event_slug order by clicks desc;
$$;

revoke all on function public.get_event_funnel(text) from public;
revoke all on function public.get_event_button_clicks(text) from public;
grant execute on function public.get_event_funnel(text) to anon, authenticated;
grant execute on function public.get_event_button_clicks(text) to anon, authenticated;

-- Dashboard queries (run in SQL Editor, never from the public browser):
-- select * from public.event_funnel where event_slug = 'pnu-halloween-2026';
-- select * from public.event_button_clicks where event_slug = 'pnu-halloween-2026'
-- order by clicks desc;
