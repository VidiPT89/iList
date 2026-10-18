-- ============================================================
-- iList - Contas reais e listas partilhadas
-- Corre este SQL UMA vez em: Supabase Dashboard → SQL Editor
--
-- Depois disto:
--   • só utilizadores autenticados acedem a dados (acesso anónimo fechado);
--   • cada lista (household) só é visível aos seus membros;
--   • entra-se numa lista apenas com o código de convite (RPC join_household).
-- ============================================================

-- ------------------------------------------------------------
-- 0. Limpa TODAS as políticas antigas destas tabelas
--    (inclui eventuais políticas abertas a "anon" usadas pela versão sem contas)
-- ------------------------------------------------------------
do $$
declare p record;
begin
  for p in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('households', 'profiles', 'shopping_items', 'household_members')
  loop
    execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 1. Códigos de convite seguros (8 caracteres, sem 0/O/1/I/L)
-- ------------------------------------------------------------
create or replace function public.generate_invite_code()
returns text
language plpgsql
set search_path = public, extensions
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea := gen_random_bytes(8);
  code text := '';
  i int;
begin
  for i in 0..7 loop
    code := code || substr(alphabet, (get_byte(bytes, i) % length(alphabet)) + 1, 1);
  end loop;
  return code;
end;
$$;

-- ------------------------------------------------------------
-- 2. Households: dono + código novo
-- ------------------------------------------------------------
alter table public.households
  add column if not exists created_by uuid references auth.users(id) on delete set null;

alter table public.households alter column invite_code set default public.generate_invite_code();
-- Troca os códigos antigos (md5, fáceis de adivinhar) por códigos novos
update public.households set invite_code = public.generate_invite_code();

-- ------------------------------------------------------------
-- 3. Membros: um utilizador pode estar em várias listas
-- ------------------------------------------------------------
create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  role         text not null default 'member' check (role in ('owner', 'member')),
  joined_at    timestamptz not null default now(),
  primary key (household_id, user_id)
);
create index if not exists household_members_user_idx on public.household_members(user_id);

-- ------------------------------------------------------------
-- 4. Perfis: só nome; household_id deixa de existir (agora é household_members)
-- ------------------------------------------------------------
alter table public.profiles drop column if exists household_id;

-- Novo utilizador: guarda o nome dado pela Apple/Google/Microsoft, se existir
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, name)
  values (
    new.id,
    new.email,
    nullif(trim(coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', '')), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- ------------------------------------------------------------
-- 5. Itens: quem adicionou (id real, além do nome mostrado)
-- ------------------------------------------------------------
alter table public.shopping_items
  add column if not exists added_by uuid references auth.users(id) on delete set null default auth.uid();
create index if not exists shopping_items_household_idx on public.shopping_items(household_id);

-- ------------------------------------------------------------
-- 6. Função de membro (security definer evita recursão nas políticas)
-- ------------------------------------------------------------
create or replace function public.is_household_member(hid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.household_members
    where household_id = hid and user_id = auth.uid()
  );
$$;

create or replace function public.is_household_owner(hid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.household_members
    where household_id = hid and user_id = auth.uid() and role = 'owner'
  );
$$;

-- ------------------------------------------------------------
-- 7. Row Level Security
-- ------------------------------------------------------------
alter table public.households        enable row level security;
alter table public.household_members enable row level security;
alter table public.profiles          enable row level security;
alter table public.shopping_items    enable row level security;

-- Nada para utilizadores anónimos
revoke all on public.households, public.household_members, public.profiles, public.shopping_items from anon;

-- Households: membros veem; só o dono altera ou apaga. Criar é via create_household().
create policy "members read household"   on public.households for select to authenticated
  using (public.is_household_member(id));
create policy "owner updates household"  on public.households for update to authenticated
  using (public.is_household_owner(id)) with check (public.is_household_owner(id));
create policy "owner deletes household"  on public.households for delete to authenticated
  using (public.is_household_owner(id));

-- Membros: veem os colegas da mesma lista; saem por si; o dono pode remover outros.
-- Entrar é só via join_household() (com código).
create policy "members read members"     on public.household_members for select to authenticated
  using (public.is_household_member(household_id));
create policy "leave or owner removes"   on public.household_members for delete to authenticated
  using (user_id = auth.uid() or public.is_household_owner(household_id));

-- Perfis: cada um só vê e edita o seu (os nomes dos colegas chegam via household_member_list())
create policy "own profile read"   on public.profiles for select to authenticated using (id = auth.uid());
create policy "own profile insert" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "own profile update" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Itens: só membros da lista
create policy "members read items"   on public.shopping_items for select to authenticated
  using (public.is_household_member(household_id));
create policy "members insert items" on public.shopping_items for insert to authenticated
  with check (public.is_household_member(household_id) and added_by = auth.uid());
create policy "members update items" on public.shopping_items for update to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "members delete items" on public.shopping_items for delete to authenticated
  using (public.is_household_member(household_id));

-- ------------------------------------------------------------
-- 8. RPCs usadas pela app
-- ------------------------------------------------------------

-- Cria uma lista nova e torna quem a criou dono
create or replace function public.create_household(p_name text)
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare h public.households;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if coalesce(trim(p_name), '') = '' or length(p_name) > 60 then
    raise exception 'invalid name';
  end if;

  insert into public.households (name, created_by)
  values (trim(p_name), auth.uid())
  returning * into h;

  insert into public.household_members (household_id, user_id, role)
  values (h.id, auth.uid(), 'owner');

  return h;
end;
$$;

-- Entra numa lista com o código de convite
create or replace function public.join_household(p_code text)
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare h public.households;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select * into h from public.households
  where invite_code = upper(trim(p_code));

  if h.id is null then raise exception 'invalid code'; end if;

  insert into public.household_members (household_id, user_id, role)
  values (h.id, auth.uid(), 'member')
  on conflict (household_id, user_id) do nothing;

  return h;
end;
$$;

-- Gera um código novo (invalida o anterior). Só o dono.
create or replace function public.rotate_invite_code(p_household_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare code text;
begin
  if not public.is_household_owner(p_household_id) then raise exception 'not owner'; end if;
  update public.households set invite_code = public.generate_invite_code()
  where id = p_household_id
  returning invite_code into code;
  return code;
end;
$$;

-- Lista os membros de uma lista com o nome (sem expor emails)
create or replace function public.household_member_list(p_household_id uuid)
returns table (user_id uuid, name text, role text, joined_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select m.user_id, p.name, m.role, m.joined_at
  from public.household_members m
  left join public.profiles p on p.id = m.user_id
  where m.household_id = p_household_id
    and public.is_household_member(p_household_id)
  order by m.joined_at;
$$;

-- Sai de uma lista. Se era o último membro, a lista e os itens são apagados;
-- se era o dono, o membro mais antigo passa a dono.
create or replace function public.leave_household(p_household_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare next_owner uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  delete from public.household_members
  where household_id = p_household_id and user_id = auth.uid();

  if not exists (select 1 from public.household_members where household_id = p_household_id) then
    delete from public.households where id = p_household_id;
  elsif not exists (select 1 from public.household_members
                    where household_id = p_household_id and role = 'owner') then
    select user_id into next_owner from public.household_members
    where household_id = p_household_id order by joined_at limit 1;
    update public.household_members set role = 'owner'
    where household_id = p_household_id and user_id = next_owner;
  end if;
end;
$$;

-- Apaga a conta (exigido pela App Store): sai de todas as listas e remove o utilizador
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare hid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  for hid in select household_id from public.household_members where user_id = auth.uid() loop
    perform public.leave_household(hid);
  end loop;

  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.create_household(text)          from public, anon;
revoke all on function public.join_household(text)            from public, anon;
revoke all on function public.rotate_invite_code(uuid)        from public, anon;
revoke all on function public.household_member_list(uuid)     from public, anon;
revoke all on function public.leave_household(uuid)           from public, anon;
revoke all on function public.delete_account()                from public, anon;
revoke all on function public.generate_invite_code()          from public, anon, authenticated;
grant execute on function public.create_household(text)       to authenticated;
grant execute on function public.join_household(text)         to authenticated;
grant execute on function public.rotate_invite_code(uuid)     to authenticated;
grant execute on function public.household_member_list(uuid)  to authenticated;
grant execute on function public.leave_household(uuid)        to authenticated;
grant execute on function public.delete_account()             to authenticated;

-- ------------------------------------------------------------
-- 9. Realtime (respeita RLS para utilizadores autenticados)
-- ------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.shopping_items;
exception when duplicate_object then null;
end $$;
