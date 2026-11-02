-- Keep-alive for the Supabase free tier.
-- 002 revoked all table access from anon, so the external scheduler's
-- GET /rest/v1/households started failing (permission denied), the scheduler
-- disabled the job and the project was paused for low activity.
-- This function touches the database and returns only `true`: no data
-- is exposed and the tables stay closed to anonymous users.
create or replace function public.keep_alive()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.households) is not null;
$$;

revoke all on function public.keep_alive() from public;
grant execute on function public.keep_alive() to anon;
