-- Wordlists + AI wordlist storage
-- Date: 2026-02-09

create extension if not exists pgcrypto;

create table if not exists public.wordlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  title text not null,
  language text not null default 'de',
  source text not null default 'manual', -- manual | ai
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wordlists_source_check check (source in ('manual', 'ai'))
);

create table if not exists public.wordlist_items (
  id uuid primary key default gen_random_uuid(),
  wordlist_id uuid not null references public.wordlists(id) on delete cascade,
  term text not null,
  position int not null,
  created_at timestamptz not null default now(),
  constraint wordlist_items_position_check check (position >= 0)
);

alter table public.wordlists
  alter column user_id set default auth.uid();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'wordlist_items_term_length_check'
  ) then
    alter table public.wordlist_items
      add constraint wordlist_items_term_length_check
      check (char_length(btrim(term)) between 1 and 64);
  end if;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.enforce_wordlist_owner()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null then
      raise exception 'auth required';
    end if;
    new.user_id := auth.uid();
  elsif tg_op = 'UPDATE' then
    if old.user_id <> auth.uid() then
      raise exception 'forbidden';
    end if;
    new.user_id := old.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_wordlists_set_updated_at on public.wordlists;
create trigger trg_wordlists_set_updated_at
before update on public.wordlists
for each row
execute procedure public.set_updated_at();

drop trigger if exists trg_wordlists_enforce_owner on public.wordlists;
create trigger trg_wordlists_enforce_owner
before insert or update on public.wordlists
for each row
execute procedure public.enforce_wordlist_owner();

create index if not exists idx_wordlists_user_created_desc
  on public.wordlists(user_id, created_at desc);

create index if not exists idx_wordlist_items_wordlist_position
  on public.wordlist_items(wordlist_id, position);

create unique index if not exists idx_wordlist_items_unique_position
  on public.wordlist_items(wordlist_id, position);

alter table public.wordlists enable row level security;
alter table public.wordlist_items enable row level security;

-- wordlists policies (owner only)
drop policy if exists wordlists_select_own on public.wordlists;
create policy wordlists_select_own
on public.wordlists
for select
using (user_id = auth.uid());

drop policy if exists wordlists_insert_own on public.wordlists;
create policy wordlists_insert_own
on public.wordlists
for insert
with check (user_id = auth.uid());

drop policy if exists wordlists_update_own on public.wordlists;
create policy wordlists_update_own
on public.wordlists
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists wordlists_delete_own on public.wordlists;
create policy wordlists_delete_own
on public.wordlists
for delete
using (user_id = auth.uid());

-- wordlist_items policies (via parent wordlists owner)
drop policy if exists wordlist_items_select_own on public.wordlist_items;
create policy wordlist_items_select_own
on public.wordlist_items
for select
using (
  exists (
    select 1
    from public.wordlists w
    where w.id = wordlist_items.wordlist_id
      and w.user_id = auth.uid()
  )
);

drop policy if exists wordlist_items_insert_own on public.wordlist_items;
create policy wordlist_items_insert_own
on public.wordlist_items
for insert
with check (
  exists (
    select 1
    from public.wordlists w
    where w.id = wordlist_items.wordlist_id
      and w.user_id = auth.uid()
  )
);

drop policy if exists wordlist_items_update_own on public.wordlist_items;
create policy wordlist_items_update_own
on public.wordlist_items
for update
using (
  exists (
    select 1
    from public.wordlists w
    where w.id = wordlist_items.wordlist_id
      and w.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.wordlists w
    where w.id = wordlist_items.wordlist_id
      and w.user_id = auth.uid()
  )
);

drop policy if exists wordlist_items_delete_own on public.wordlist_items;
create policy wordlist_items_delete_own
on public.wordlist_items
for delete
using (
  exists (
    select 1
    from public.wordlists w
    where w.id = wordlist_items.wordlist_id
      and w.user_id = auth.uid()
  )
);
