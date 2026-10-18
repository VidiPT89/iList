-- ============================================================
-- iList - Setup da base de dados no Supabase
-- Corre este SQL em: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Tabela de agregados familiares
create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text unique not null default upper(substring(md5(random()::text), 1, 8)),
  created_at timestamptz default now()
);

-- 2. Perfis dos utilizadores (ligados ao auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  household_id uuid references public.households(id) on delete set null
);

-- Cria perfil automaticamente quando um utilizador se regista
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 3. Itens da lista de compras
create table public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  category text not null default 'Outros',
  quantity text,
  unit text,
  is_checked boolean not null default false,
  added_by_name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Atualiza updated_at automaticamente
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger shopping_items_updated_at
  before update on public.shopping_items
  for each row execute procedure public.update_updated_at();

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================

alter table public.households enable row level security;
alter table public.profiles enable row level security;
alter table public.shopping_items enable row level security;

-- Households: só vês o teu agregado
create policy "Users see their household"
  on public.households for select
  using (id = (select household_id from public.profiles where id = auth.uid()));

create policy "Users insert household"
  on public.households for insert
  with check (true);

create policy "Users update their household"
  on public.households for update
  using (id = (select household_id from public.profiles where id = auth.uid()));

-- Profiles: cada um vê e edita o seu perfil
create policy "Users manage own profile"
  on public.profiles for all
  using (id = auth.uid());

-- Shopping items: só quem está no mesmo agregado
create policy "Household members see items"
  on public.shopping_items for select
  using (household_id = (select household_id from public.profiles where id = auth.uid()));

create policy "Household members insert items"
  on public.shopping_items for insert
  with check (household_id = (select household_id from public.profiles where id = auth.uid()));

create policy "Household members update items"
  on public.shopping_items for update
  using (household_id = (select household_id from public.profiles where id = auth.uid()));

create policy "Household members delete items"
  on public.shopping_items for delete
  using (household_id = (select household_id from public.profiles where id = auth.uid()));

-- ============================================================
-- Realtime (para sincronização em tempo real)
-- ============================================================

alter publication supabase_realtime add table public.shopping_items;
