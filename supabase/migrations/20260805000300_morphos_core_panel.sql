-- MORPHOS — panel de morphos_core (§3.1)
--
-- morphos_core es super admin de todo el sistema: ve y gestiona cualquier
-- empresa sin pertenecer a ninguna. Las policies del baseline ya le dan lectura
-- y escritura sobre companies, company_members, work_sites y admin_work_sites;
-- aqui se completa lo que faltaba para que pueda operar de verdad:
--
--   1. Una vista de resumen por empresa para el panel.
--   2. Poder editar cualquier perfil (corregir un nombre o un correo mal puesto
--      es soporte de primera linea).
--   3. Que las RPC de gestion de equipo lo acepten, no solo al owner.
--
-- Lo que NO cambia: confirmar o rechazar `ledger_entries` sigue exigiendo que
-- la empresa tenga contratada la supervision (regla no-negociable #2 de
-- CONTEXT.md). Esa puerta es deliberada — es lo que permite distinguir en el
-- historial "confirmado por la empresa" de "confirmado por soporte externo".
-- Un super admin que pueda acreditar saldo en cualquier empresa sin que esa
-- empresa lo haya contratado destruiria esa distincion.

-- ============================================================================
-- 1. Vista de resumen por empresa
-- ============================================================================
-- security_invoker: la vista no es un atajo de permisos. morphos_core ve todas
-- las filas porque sus policies se lo permiten; un owner que consulte esta
-- misma vista ve solo la suya, y le sirve igual para el bloque "generado en la
-- semana" del §4.1.

create view public.v_company_overview
with (security_invoker = true) as
select
  c.id as company_id,
  c.name,
  c.plan,
  c.jurisdiction,
  c.compliance_pending,
  c.supervision_contracted,
  c.created_at,
  (
    select count(*)
    from public.company_members m
    where m.company_id = c.id and m.status = 'activo'
  ) as active_members,
  (
    select count(*)
    from public.company_members m
    where m.company_id = c.id and m.role = 'owner'
  ) as owners,
  (
    select count(*)
    from public.work_sites w
    where w.company_id = c.id and w.status = 'activa'
  ) as active_work_sites,
  -- §4.1: la semana en curso arranca en lunes.
  (
    select coalesce(sum(le.amount), 0)
    from public.ledger_entries le
    where le.company_id = c.id
      and le.status = 'confirmado'
      and le.type in ('venta', 'afiliacion')
      and le.period_ref >= date_trunc('week', current_date)::date
  ) as week_income,
  (
    select count(*)
    from public.ledger_entries le
    where le.company_id = c.id and le.status = 'pendiente'
  ) as pending_entries
from public.companies c;

grant select on public.v_company_overview to authenticated;

-- ============================================================================
-- 2. morphos_core puede corregir cualquier perfil
-- ============================================================================
-- El perfil no guarda rol ni empresa, asi que esto no escala permisos: lo peor
-- que permite es cambiar un nombre o un correo. Queda auditado igual que
-- cualquier otra accion de soporte (§3.5).

create policy profiles_update_morphos_core on public.profiles
  for update to authenticated
  using ((select private.is_morphos_core()))
  with check ((select private.is_morphos_core()));

-- ============================================================================
-- 3. Las RPC de gestion aceptan tambien a morphos_core
-- ============================================================================

create or replace function public.invite_team_member(
  p_company_id uuid,
  p_full_name text,
  p_email text,
  p_role text,
  p_full_day_value numeric default null,
  p_half_day_value numeric default null,
  p_pay_period text default 'semanal'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_profile_type text;
  v_member_id uuid;
begin
  if not (
    (select private.is_company_owner(p_company_id))
    or (select private.is_morphos_core())
  ) then
    raise exception 'Solo el dueno de la empresa o el equipo de MORPHOS pueden dar de alta al equipo.'
      using errcode = 'insufficient_privilege';
  end if;

  if p_role not in ('administrador', 'trabajador', 'vendedor', 'afiliado') then
    raise exception 'Rol no valido para una invitacion de equipo: %', p_role
      using errcode = 'check_violation';
  end if;

  if p_email is null or p_email = '' then
    raise exception 'Hace falta un correo para invitar a alguien.'
      using errcode = 'check_violation';
  end if;

  -- §3.2: solo el trabajador ficha por bloques; el resto registra eventos.
  v_profile_type := case when p_role = 'trabajador' then 'con_horario' else 'sin_horario' end;

  select id into v_profile_id from public.profiles where lower(email) = lower(p_email);

  if v_profile_id is null then
    insert into public.profiles (full_name, email)
    values (p_full_name, lower(p_email))
    returning id into v_profile_id;
  end if;

  if exists (
    select 1 from public.company_members
    where company_id = p_company_id and profile_id = v_profile_id
  ) then
    raise exception 'Esa persona ya forma parte de la empresa.'
      using errcode = 'unique_violation';
  end if;

  insert into public.company_members (
    company_id, profile_id, role, profile_type,
    full_day_value, half_day_value, pay_period
  ) values (
    p_company_id, v_profile_id, p_role, v_profile_type,
    p_full_day_value, p_half_day_value, coalesce(p_pay_period, 'semanal')
  ) returning id into v_member_id;

  return v_member_id;
end;
$$;

create or replace function public.set_admin_work_sites(
  p_member_id uuid,
  p_work_site_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid;
  v_role text;
  v_actor_member_id uuid;
  v_assigned integer;
begin
  select company_id, role into v_company_id, v_role
  from public.company_members where id = p_member_id;

  if v_company_id is null then
    raise exception 'Esa pertenencia no existe.' using errcode = 'no_data_found';
  end if;

  if not (
    (select private.is_company_owner(v_company_id))
    or (select private.is_morphos_core())
  ) then
    raise exception 'Solo el dueno de la empresa o el equipo de MORPHOS asignan obras.'
      using errcode = 'insufficient_privilege';
  end if;

  if v_role is distinct from 'administrador' then
    raise exception 'Solo un administrador puede tener obras asignadas.'
      using errcode = 'check_violation';
  end if;

  -- Quien firma la asignacion. morphos_core no pertenece a la empresa, asi que
  -- no tiene pertenencia propia: en ese caso firma el owner titular, que es
  -- quien responde por la empresa.
  select m.id into v_actor_member_id
  from public.company_members m
  where m.company_id = v_company_id
    and m.profile_id = (select private.app_profile_id());

  if v_actor_member_id is null then
    select m.id into v_actor_member_id
    from public.company_members m
    where m.company_id = v_company_id
      and m.role = 'owner'
    order by m.is_billing_owner desc, m.created_at
    limit 1;
  end if;

  if v_actor_member_id is null then
    raise exception 'La empresa no tiene ningun owner que pueda firmar la asignacion.'
      using errcode = 'no_data_found';
  end if;

  delete from public.admin_work_sites
  where member_id = p_member_id
    and (p_work_site_ids is null or work_site_id <> all (p_work_site_ids));

  insert into public.admin_work_sites (company_id, member_id, work_site_id, assigned_by)
  select v_company_id, p_member_id, ws.id, v_actor_member_id
  from public.work_sites ws
  where ws.company_id = v_company_id
    and ws.id = any (coalesce(p_work_site_ids, '{}'::uuid[]))
  on conflict (member_id, work_site_id) do nothing;

  select count(*) into v_assigned
  from public.admin_work_sites where member_id = p_member_id;

  return v_assigned;
end;
$$;

-- ============================================================================
-- 4. Contratar o cancelar la supervision de una empresa (regla #2)
-- ============================================================================
-- Es la unica palanca que decide si morphos_core puede confirmar en nombre de
-- una empresa, asi que se mueve por una funcion propia y auditable en vez de
-- por un update suelto: deja la fecha coherente con el estado.

create or replace function public.set_supervision_contracted(
  p_company_id uuid,
  p_contracted boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (
    (select private.is_morphos_core())
    or (select private.is_company_owner(p_company_id))
  ) then
    raise exception 'Solo el equipo de MORPHOS o el dueno pueden cambiar la supervision contratada.'
      using errcode = 'insufficient_privilege';
  end if;

  update public.companies
  set supervision_contracted = p_contracted,
      supervision_contracted_at = case when p_contracted then now() else null end
  where id = p_company_id;

  return p_contracted;
end;
$$;

revoke execute on function public.set_supervision_contracted(uuid, boolean) from public, anon;
grant execute on function public.set_supervision_contracted(uuid, boolean) to authenticated;
