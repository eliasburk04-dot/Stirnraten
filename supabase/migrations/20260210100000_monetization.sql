-- Monetization: Premium flag + AI generation usage quota (Free 3/day)
-- Date: 2026-02-10

create extension if not exists pgcrypto;

-- 1) Profiles / entitlements (server-authoritative premium flag).
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  premium boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_profiles_set_updated_at on public.profiles;
create trigger trg_profiles_set_updated_at
before update on public.profiles
for each row
execute procedure public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
on public.profiles
for select
using (user_id = auth.uid());

-- No insert/update/delete policies on profiles (must be updated via service role / backend).

-- 2) AI generation usage (quota counter per user + Europe/Berlin date key).
create table if not exists public.ai_generation_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date_key text not null,
  count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_generation_usage_date_key_check check (date_key ~ '^\\d{4}-\\d{2}-\\d{2}$'),
  constraint ai_generation_usage_count_check check (count >= 0)
);

create unique index if not exists idx_ai_generation_usage_user_date
  on public.ai_generation_usage(user_id, date_key);

drop trigger if exists trg_ai_generation_usage_set_updated_at on public.ai_generation_usage;
create trigger trg_ai_generation_usage_set_updated_at
before update on public.ai_generation_usage
for each row
execute procedure public.set_updated_at();

alter table public.ai_generation_usage enable row level security;

drop policy if exists ai_generation_usage_select_own on public.ai_generation_usage;
create policy ai_generation_usage_select_own
on public.ai_generation_usage
for select
using (user_id = auth.uid());

-- 3) Atomic quota consumption. Called from Edge Function before generating.
create or replace function public.consume_ai_generation(p_date_key text)
returns table (
  allowed boolean,
  is_premium boolean,
  used int,
  quota_limit int,
  date_key text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_premium boolean := false;
  v_limit int := 3;
  v_used int := 0;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'auth required';
  end if;

  select coalesce(p.premium, false)
  into v_premium
  from public.profiles p
  where p.user_id = v_uid;

  if v_premium then
    allowed := true;
    is_premium := true;
    used := 0;
    quota_limit := v_limit;
    date_key := p_date_key;
    return next;
    return;
  end if;

  insert into public.ai_generation_usage(user_id, date_key, count)
  values (v_uid, p_date_key, 1)
  on conflict (user_id, date_key) do update
    set count = public.ai_generation_usage.count + 1,
        updated_at = now()
    where public.ai_generation_usage.count < v_limit
  returning public.ai_generation_usage.count into v_used;

  if not found then
    select u.count into v_used
    from public.ai_generation_usage u
    where u.user_id = v_uid and u.date_key = p_date_key;

    allowed := false;
    is_premium := false;
    used := coalesce(v_used, v_limit);
    quota_limit := v_limit;
    date_key := p_date_key;
    return next;
    return;
  end if;

  allowed := true;
  is_premium := false;
  used := v_used;
  quota_limit := v_limit;
  date_key := p_date_key;
  return next;
end;
$$;

grant execute on function public.consume_ai_generation(text) to authenticated, anon;
