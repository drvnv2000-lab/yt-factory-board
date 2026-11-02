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
