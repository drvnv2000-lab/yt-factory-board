-- Run once in Supabase → SQL Editor. Creates tables, limits access to emails listed in public.owners (add yours separately), enables realtime.
create table if not exists public.owners (email text primary key);
alter table public.owners enable row level security;
drop policy if exists owners_self on public.owners;
create policy owners_self on public.owners for select to authenticated using (email = auth.jwt()->>'email');
-- then, separately (not in this repo): insert into public.owners(email) values ('<your email>');
create table if not exists public.channels (id text primary key, data jsonb not null default '{}'::jsonb, updated_at timestamptz default now());
create table if not exists public.videos   (id text primary key, data jsonb not null default '{}'::jsonb, updated_at timestamptz default now());
create table if not exists public.swipe    (id text primary key, data jsonb not null default '{}'::jsonb, updated_at timestamptz default now());
do $$ declare t text; begin
  foreach t in array array['channels','videos','swipe'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists owner_all on public.%I', t);
    execute format($p$create policy owner_all on public.%I for all to authenticated using (exists (select 1 from public.owners o where o.email = auth.jwt()->>'email')) with check (exists (select 1 from public.owners o where o.email = auth.jwt()->>'email'))$p$, t);
  end loop;
end $$;
alter publication supabase_realtime add table public.channels, public.videos, public.swipe;

-- 2026-11-02: passcode access (no email login). Run once; set the passcode separately (not in this repo):
--   insert into private.board_key(key) values ('<passcode>');
create schema if not exists private;
create table if not exists private.board_key (key text primary key);
revoke all on schema private from anon, authenticated;
create or replace function public.board_ok() returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.board_key k
    where k.key = coalesce(nullif(current_setting('request.headers', true), '')::json->>'x-board-key', ''));
$$;
revoke all on function public.board_ok() from public;
grant execute on function public.board_ok() to anon, authenticated;
do $$ declare t text; begin
  foreach t in array array['channels','videos','swipe'] loop
    execute format('drop policy if exists key_all on public.%I', t);
    execute format('create policy key_all on public.%I for all to anon, authenticated using (public.board_ok()) with check (public.board_ok())', t);
  end loop;
end $$;

-- 2026-11-03: pipeline runner. jobs = queue the board writes and the laptop runner executes; runner = laptop heartbeat + readiness.
create table if not exists public.jobs   (id text primary key, data jsonb not null default '{}'::jsonb, updated_at timestamptz default now());
create table if not exists public.runner (id text primary key, data jsonb not null default '{}'::jsonb, updated_at timestamptz default now());
do $$ declare t text; begin
  foreach t in array array['jobs','runner'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists key_all on public.%I', t);
    execute format('create policy key_all on public.%I for all to anon, authenticated using (public.board_ok()) with check (public.board_ok())', t);
  end loop;
end $$;
create index if not exists jobs_status on public.jobs ((data->>'status'));
