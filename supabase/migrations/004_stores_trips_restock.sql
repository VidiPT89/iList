-- ============================================================
-- iList - Percurso da loja, compras (histórico) e despesas
-- Corre este SQL UMA vez em: Supabase Dashboard → SQL Editor (depois da 002)
--
-- Depois disto:
--   • cada lista tem lojas com a ordem dos corredores (categorias);
--   • "Terminar compra" guarda o que foi comprado, quanto custou e quem pagou;
--   • o histórico alimenta as sugestões de reposição e o acerto de contas.
-- Tudo isolado por lista com RLS, como as tabelas da 002.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Lojas: ordem das categorias pelos corredores
-- ------------------------------------------------------------
create table if not exists public.stores (
  id             uuid primary key default gen_random_uuid(),
  household_id   uuid not null references public.households(id) on delete cascade,
  name           text not null check (length(trim(name)) between 1 and 40),
  category_order text[] not null default '{}',
  created_at     timestamptz not null default now()
);
create index if not exists stores_household_idx on public.stores(household_id);

-- ------------------------------------------------------------
-- 2. Compras feitas (uma por "Terminar compra")
-- ------------------------------------------------------------
create table if not exists public.trips (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households(id) on delete cascade,
  store_name    text check (store_name is null or length(store_name) <= 40),
  total_cents   integer check (total_cents is null or total_cents between 0 and 10000000),
  paid_by       uuid references auth.users(id) on delete set null,
  paid_by_name  text,
  item_count    integer not null default 0,
  settled       boolean not null default false,
  finished_at   timestamptz not null default now()
);
create index if not exists trips_household_idx on public.trips(household_id, finished_at desc);

-- ------------------------------------------------------------
-- 3. Artigos comprados (histórico para a reposição)
-- ------------------------------------------------------------
create table if not exists public.purchases (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households(id) on delete cascade,
  trip_id       uuid references public.trips(id) on delete cascade,
  name          text not null,
  category      text not null default 'Outros',
  quantity      text,
  unit          text,
  purchased_at  timestamptz not null default now()
);
create index if not exists purchases_household_idx on public.purchases(household_id, purchased_at desc);

-- ------------------------------------------------------------
-- 4. Row Level Security
-- ------------------------------------------------------------
alter table public.stores    enable row level security;
alter table public.trips     enable row level security;
alter table public.purchases enable row level security;

revoke all on public.stores, public.trips, public.purchases from anon;

-- Lojas: qualquer membro gere as lojas da lista
drop policy if exists "members read stores" on public.stores;
create policy "members read stores"   on public.stores for select to authenticated
  using (public.is_household_member(household_id));
drop policy if exists "members insert stores" on public.stores;
create policy "members insert stores" on public.stores for insert to authenticated
  with check (public.is_household_member(household_id));
drop policy if exists "members update stores" on public.stores;
create policy "members update stores" on public.stores for update to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
drop policy if exists "members delete stores" on public.stores;
create policy "members delete stores" on public.stores for delete to authenticated
  using (public.is_household_member(household_id));

-- Compras: criadas só via finish_trip(); membros leem, acertam contas e apagam
drop policy if exists "members read trips" on public.trips;
create policy "members read trips"   on public.trips for select to authenticated
  using (public.is_household_member(household_id));
drop policy if exists "members update trips" on public.trips;
create policy "members update trips" on public.trips for update to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
drop policy if exists "members delete trips" on public.trips;
create policy "members delete trips" on public.trips for delete to authenticated
  using (public.is_household_member(household_id));

-- Histórico: só leitura para os membros (escrito por finish_trip())
drop policy if exists "members read purchases" on public.purchases;
create policy "members read purchases" on public.purchases for select to authenticated
  using (public.is_household_member(household_id));

-- ------------------------------------------------------------
-- 5. Terminar compra: guarda a compra e o histórico, e tira do carrinho os artigos comprados
-- ------------------------------------------------------------
create or replace function public.finish_trip(
  p_household_id uuid,
  p_store_name   text,
  p_total_cents  integer,
  p_paid_by      uuid
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  t public.trips;
  payer_name text;
begin
  if not public.is_household_member(p_household_id) then raise exception 'not member'; end if;
  if p_total_cents is not null and (p_total_cents < 0 or p_total_cents > 10000000) then
    raise exception 'invalid total';
  end if;
  if p_paid_by is not null and not exists (
    select 1 from public.household_members
    where household_id = p_household_id and user_id = p_paid_by
  ) then
    raise exception 'payer not member';
  end if;
  if not exists (select 1 from public.shopping_items
                 where household_id = p_household_id and is_checked) then
    raise exception 'nothing checked';
  end if;

  select name into payer_name from public.profiles where id = p_paid_by;

  insert into public.trips (household_id, store_name, total_cents, paid_by, paid_by_name, item_count)
  values (
    p_household_id,
    nullif(left(trim(coalesce(p_store_name, '')), 40), ''),
    p_total_cents,
    p_paid_by,
    payer_name,
    (select count(*) from public.shopping_items where household_id = p_household_id and is_checked)
  )
  returning * into t;

  insert into public.purchases (household_id, trip_id, name, category, quantity, unit, purchased_at)
  select household_id, t.id, name, category, quantity, unit, t.finished_at
  from public.shopping_items
  where household_id = p_household_id and is_checked;

  delete from public.shopping_items where household_id = p_household_id and is_checked;

  return t;
end;
$$;

revoke all on function public.finish_trip(uuid, text, integer, uuid) from public, anon;
grant execute on function public.finish_trip(uuid, text, integer, uuid) to authenticated;
