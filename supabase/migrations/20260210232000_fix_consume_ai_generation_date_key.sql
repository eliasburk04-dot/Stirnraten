-- Fix consume_ai_generation: normalize date key to satisfy ai_generation_usage_date_key_check
-- Date: 2026-02-10

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
  v_date_key text;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'auth required';
  end if;

  -- Always enforce a valid YYYY-MM-DD key in Europe/Berlin.
  v_date_key := btrim(coalesce(p_date_key, ''));
  if v_date_key !~ '^\\d{4}-\\d{2}-\\d{2}$' then
    v_date_key := to_char((now() at time zone 'Europe/Berlin'), 'YYYY-MM-DD');
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
    date_key := v_date_key;
    return next;
    return;
  end if;

  insert into public.ai_generation_usage as agu (user_id, date_key, count)
  values (v_uid, v_date_key, 1)
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
      and u.date_key = v_date_key;

    allowed := false;
    is_premium := false;
    used := coalesce(v_used, v_limit);
    quota_limit := v_limit;
    date_key := v_date_key;
    return next;
    return;
  end if;

  allowed := true;
  is_premium := false;
  used := v_used;
  quota_limit := v_limit;
  date_key := v_date_key;
  return next;
end;
$$;

grant execute on function public.consume_ai_generation(text) to authenticated, anon;

