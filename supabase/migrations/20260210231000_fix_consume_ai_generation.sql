-- Fix consume_ai_generation: avoid ambiguous column references (date_key)
-- Date: 2026-02-10

-- Root cause:
-- The function returns an OUT parameter named "date_key". In plpgsql, OUT parameters
-- are variables. Using `on conflict (user_id, date_key)` can then produce
-- "column reference date_key is ambiguous" because `date_key` can refer to either
-- the table column or the OUT variable in some contexts.
--
-- Fix:
-- 1) Attach a unique CONSTRAINT to the existing unique index.
-- 2) Use `on conflict on constraint ...` to avoid referencing the identifier "date_key".

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    where c.conname = 'ai_generation_usage_user_date_unique'
      and c.conrelid = 'public.ai_generation_usage'::regclass
  ) then
    -- Reuse the existing unique index created by the previous migration.
    alter table public.ai_generation_usage
      add constraint ai_generation_usage_user_date_unique
      unique using index idx_ai_generation_usage_user_date;
  end if;
end;
$$;

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

  insert into public.ai_generation_usage as agu (user_id, date_key, count)
  values (v_uid, p_date_key, 1)
  on conflict on constraint ai_generation_usage_user_date_unique do update
    set count = agu.count + 1,
        updated_at = now()
    where agu.count < v_limit
  returning agu.count into v_used;

  if not found then
    select u.count
    into v_used
    from public.ai_generation_usage u
    where u.user_id = v_uid
      and u.date_key = p_date_key;

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
