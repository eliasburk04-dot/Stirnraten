-- Fix ai_generation_usage_date_key_check: Postgres regex does not reliably support \d
-- Date: 2026-02-10

alter table public.ai_generation_usage
  drop constraint if exists ai_generation_usage_date_key_check;

alter table public.ai_generation_usage
  add constraint ai_generation_usage_date_key_check
  check (date_key ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

