-- MORPHOS — RLS sobre el modelo de pertenencias (§2.1, §3.1, §3.3, §5.10)
--
-- Alcance por rol, tal como lo define el documento. El rol es de la pertenencia,
-- asi que todo se evalua siempre "en esta empresa":
--   owner         — toda su empresa, todas sus obras
--   administrador — solo las obras que el owner le asigno (admin_work_sites)
--   trabajador    — su propio turno, sus propios registros y su saldo
--   vendedor      — sus propias ventas y su saldo
--   afiliado      — sus propios referidos y su saldo
--   morphos_core  — cualquier empresa, en modo soporte
--
-- Empresa activa: la RLS deja ver *todas* las empresas de las que la persona es
-- miembro, y la app filtra por la que tenga seleccionada. El "cambio de empresa"
-- es de interfaz, no de permisos — mezclar dos empresas de la misma persona
-- seria un fallo de pantalla, nunca una fuga entre cuentas distintas.
--
-- Todos los helpers son SECURITY DEFINER en `private` para poder leer las
-- tablas de identidad sin recursion de policies. Ninguno acepta un id como
-- parametro de identidad: la identidad sale siempre de auth.uid(). Las llamadas
-- van envueltas en (select ...) para evaluarse una vez por consulta.

-- ============================================================================
-- 1. Helpers de identidad
-- ============================================================================

create or replace function private.app_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.profiles p
  where p.auth_user_id = (select auth.uid())
  limit 1;
$$;

-- Equipo interno de MORPHOS: super admin de todo el sistema (§3.1).
create or replace function private.is_morphos_core()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.auth_user_id = (select auth.uid())
      and p.platform_role = 'morphos_core'
  );
$$;

-- ============================================================================
-- 2. Helpers de alcance
-- ============================================================================

-- Pertenece a la empresa con cualquier rol activo. Es el alcance de lo que
-- todo el equipo puede ver: la ficha de su empresa, el catalogo de obras.
create or replace function private.is_company_member(target_company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_company is not null and exists (
    select 1
    from public.company_members m
    join public.profiles p on p.id = m.profile_id
    where m.company_id = target_company
      and m.status = 'activo'
      and p.auth_user_id = (select auth.uid())
  );
$$;

-- Dueno de esa empresa. Con varios socios (§2.1) todos dan true.
create or replace function private.is_company_owner(target_company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_company is not null and exists (
    select 1
    from public.company_members m
    join public.profiles p on p.id = m.profile_id
    where m.company_id = target_company
      and m.status = 'activo'
      and m.role = 'owner'
      and p.auth_user_id = (select auth.uid())
  );
$$;

-- Administrador con esa obra concreta asignada. Sin fila en admin_work_sites
-- no alcanza nada: es lo que lo distingue de un segundo owner.
create or replace function private.is_site_admin(target_site uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_site is not null and exists (
    select 1
    from public.admin_work_sites aws
    join public.company_members m on m.id = aws.member_id
    join public.profiles p on p.id = m.profile_id
    where aws.work_site_id = target_site
      and m.status = 'activo'
      and m.role = 'administrador'
      and p.auth_user_id = (select auth.uid())
  );
$$;

-- Owner de la empresa, o administrador con al menos una obra asignada en ella.
create or replace function private.manages_company(target_company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_company_owner(target_company))
    or (
      target_company is not null and exists (
        select 1
        from public.admin_work_sites aws
        join public.company_members m on m.id = aws.member_id
        join public.profiles p on p.id = m.profile_id
        where aws.company_id = target_company
          and m.status = 'activo'
          and m.role = 'administrador'
          and p.auth_user_id = (select auth.uid())
      )
    );
$$;

-- Puede gestionar esa pertenencia: el owner de su empresa siempre; el
-- administrador solo si comparten obra (turno asignado o asignacion de admin).
create or replace function private.can_manage_member(target_member uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.company_members target
    where target.id = target_member
      and (
        (select private.is_company_owner(target.company_id))
        or exists (
          select 1
          from public.assigned_shifts s
          where s.member_id = target.id
            and (select private.is_site_admin(s.work_site_id))
        )
        or exists (
          select 1
          from public.admin_work_sites a
          where a.member_id = target.id
            and (select private.is_site_admin(a.work_site_id))
        )
      )
  );
$$;

-- Regla no-negociable #2: solo la cuenta maestra confirma. morphos_core puede
-- hacerlo unicamente si la empresa contrato el servicio de supervision.
create or replace function private.can_confirm_for(target_company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_company_owner(target_company))
    or (
      (select private.is_morphos_core())
      and exists (
        select 1
        from public.companies c
        where c.id = target_company
          and c.supervision_contracted
      )
    );
$$;

-- La pertenencia es del propio llamante.
create or replace function private.owns_member(target_member uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_member is not null and exists (
    select 1
    from public.company_members m
    where m.id = target_member
      and m.profile_id = (select private.app_profile_id())
  );
$$;

revoke execute on function private.app_profile_id() from public, anon;
revoke execute on function private.is_morphos_core() from public, anon;
revoke execute on function private.is_company_member(uuid) from public, anon;
revoke execute on function private.is_company_owner(uuid) from public, anon;
revoke execute on function private.is_site_admin(uuid) from public, anon;
revoke execute on function private.manages_company(uuid) from public, anon;
revoke execute on function private.can_manage_member(uuid) from public, anon;
revoke execute on function private.can_confirm_for(uuid) from public, anon;
revoke execute on function private.owns_member(uuid) from public, anon;

grant usage on schema private to authenticated;
grant execute on function private.app_profile_id() to authenticated;
grant execute on function private.is_morphos_core() to authenticated;
grant execute on function private.is_company_member(uuid) to authenticated;
grant execute on function private.is_company_owner(uuid) to authenticated;
grant execute on function private.is_site_admin(uuid) to authenticated;
grant execute on function private.manages_company(uuid) to authenticated;
grant execute on function private.can_manage_member(uuid) to authenticated;
grant execute on function private.can_confirm_for(uuid) to authenticated;
grant execute on function private.owns_member(uuid) to authenticated;

-- ============================================================================
-- 3. RLS activada en todas las tablas
-- ============================================================================

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.company_members enable row level security;
alter table public.work_sites enable row level security;
alter table public.admin_work_sites enable row level security;
alter table public.assigned_shifts enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.checkin_events enable row level security;
alter table public.compliance_rules enable row level security;
alter table public.compliance_alerts enable row level security;
alter table public.modification_requests enable row level security;

-- --- profiles ---------------------------------------------------------------
-- Se ve el propio perfil, y el de la gente a la que se gestiona en alguna
-- empresa. Un perfil no revela en que otras empresas esta esa persona: eso lo
-- decide company_members, que se filtra aparte.

create policy profiles_select on public.profiles
  for select to authenticated
  using (
    auth_user_id = (select auth.uid())
    or (select private.is_morphos_core())
    or exists (
      select 1
      from public.company_members m
      where m.profile_id = id
        and (select private.can_manage_member(m.id))
    )
  );

-- Cada quien edita su propio nombre. El rol no esta aqui, asi que esto no
-- puede escalar permisos.
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (auth_user_id = (select auth.uid()))
  with check (auth_user_id = (select auth.uid()));

-- --- companies --------------------------------------------------------------

create policy companies_select on public.companies
  for select to authenticated
  using (
    (select private.is_company_member(id))
    or (select private.is_morphos_core())
  );

create policy companies_update on public.companies
  for update to authenticated
  using (
    (select private.is_company_owner(id))
    or (select private.is_morphos_core())
  )
  with check (
    (select private.is_company_owner(id))
    or (select private.is_morphos_core())
  );

-- --- company_members — gestion de usuarios ----------------------------------
-- Cada quien ve sus propias pertenencias (las necesita para el selector de
-- empresa). El owner ve y gestiona a todo su equipo; el administrador, a la
-- gente de sus obras.

create policy company_members_select on public.company_members
  for select to authenticated
  using (
    profile_id = (select private.app_profile_id())
    or (select private.is_company_owner(company_id))
    or (select private.can_manage_member(id))
    or (select private.is_morphos_core())
  );

-- Alta de equipo: solo el owner de esa empresa. El administrador gestiona la
-- operacion de sus obras, no la composicion de la plantilla.
create policy company_members_insert_owner on public.company_members
  for insert to authenticated
  with check (
    (select private.is_company_owner(company_id))
    or (select private.is_morphos_core())
  );

-- El administrador puede editar a la gente de sus obras (p. ej. desbloquear un
-- check-in), pero no puede tocar al owner ni a otro administrador.
create policy company_members_update on public.company_members
  for update to authenticated
  using (
    (select private.is_company_owner(company_id))
    or (select private.is_morphos_core())
    or (
      role in ('trabajador', 'vendedor', 'afiliado')
      and (select private.can_manage_member(id))
    )
  )
  with check (
    (select private.is_company_owner(company_id))
    or (select private.is_morphos_core())
    or (
      role in ('trabajador', 'vendedor', 'afiliado')
      and (select private.can_manage_member(id))
    )
  );

-- --- work_sites — obras ------------------------------------------------------

create policy work_sites_select on public.work_sites
  for select to authenticated
  using (
    (select private.is_company_member(company_id))
    or (select private.is_morphos_core())
  );

-- Crear y borrar obras es del owner; el administrador solo edita las suyas.
create policy work_sites_insert_owner on public.work_sites
  for insert to authenticated
  with check (
    (select private.is_company_owner(company_id))
    or (select private.is_morphos_core())
  );

create policy work_sites_update on public.work_sites
  for update to authenticated
  using (
    (select private.is_company_owner(company_id))
    or (select private.is_site_admin(id))
    or (select private.is_morphos_core())
  )
  with check (
    (select private.is_company_owner(company_id))
    or (select private.is_site_admin(id))
    or (select private.is_morphos_core())
  );

create policy work_sites_delete_owner on public.work_sites
  for delete to authenticated
  using (
    (select private.is_company_owner(company_id))
    or (select private.is_morphos_core())
  );

-- --- admin_work_sites — quien gestiona que obra ------------------------------
-- Asignar es una decision del owner: si el administrador pudiera escribir aqui
-- se auto-ampliaria el alcance.

create policy admin_work_sites_select on public.admin_work_sites
  for select to authenticated
  using (
    (select private.owns_member(member_id))
    or (select private.is_company_owner(company_id))
    or (select private.is_morphos_core())
  );

create policy admin_work_sites_insert_owner on public.admin_work_sites
  for insert to authenticated
  with check (
    (select private.is_company_owner(company_id))
    or (select private.is_morphos_core())
  );

create policy admin_work_sites_delete_owner on public.admin_work_sites
  for delete to authenticated
  using (
    (select private.is_company_owner(company_id))
    or (select private.is_morphos_core())
  );

-- --- assigned_shifts ---------------------------------------------------------

create policy assigned_shifts_select on public.assigned_shifts
  for select to authenticated
  using (
    (select private.owns_member(member_id))
    or (select private.is_company_owner(company_id))
    or (select private.is_site_admin(work_site_id))
    or (select private.is_morphos_core())
  );

create policy assigned_shifts_insert on public.assigned_shifts
  for insert to authenticated
  with check (
    (select private.is_company_owner(company_id))
    or (select private.is_site_admin(work_site_id))
  );

create policy assigned_shifts_update on public.assigned_shifts
  for update to authenticated
  using (
    (select private.is_company_owner(company_id))
    or (select private.is_site_admin(work_site_id))
  )
  with check (
    (select private.is_company_owner(company_id))
    or (select private.is_site_admin(work_site_id))
  );

create policy assigned_shifts_delete on public.assigned_shifts
  for delete to authenticated
  using (
    (select private.is_company_owner(company_id))
    or (select private.is_site_admin(work_site_id))
  );

-- --- ledger_entries ----------------------------------------------------------

create policy ledger_entries_select on public.ledger_entries
  for select to authenticated
  using (
    origin_profile_id = (select private.app_profile_id())
    or (select private.is_company_owner(company_id))
    or (select private.is_site_admin(work_site_id))
    or (select private.is_morphos_core())
  );

-- Cada quien registra lo suyo, siempre como pendiente y siempre con una
-- pertenencia propia (el trigger comprueba que sea de esa empresa).
create policy ledger_entries_insert_own on public.ledger_entries
  for insert to authenticated
  with check (
    origin_profile_id = (select private.app_profile_id())
    and (origin_member_id is null or (select private.owns_member(origin_member_id)))
    and status = 'pendiente'
    and confirmed_by is null
  );

-- Confirmar o rechazar: solo la cuenta maestra (o supervision contratada).
-- El administrador opera la obra, pero no acredita saldo.
create policy ledger_entries_confirm on public.ledger_entries
  for update to authenticated
  using ((select private.can_confirm_for(company_id)))
  with check ((select private.can_confirm_for(company_id)));

-- --- checkin_events ----------------------------------------------------------
-- El trabajador escribe su evidencia pero no puede leerla: las horas reales
-- son informacion de administracion.

create policy checkin_events_insert_own on public.checkin_events
  for insert to authenticated
  with check ((select private.owns_member(member_id)));

create policy checkin_events_update_own on public.checkin_events
  for update to authenticated
  using ((select private.owns_member(member_id)))
  with check ((select private.owns_member(member_id)));

create policy checkin_events_select on public.checkin_events
  for select to authenticated
  using (
    (select private.is_company_owner(company_id))
    or (select private.is_site_admin(work_site_id))
    or (select private.is_morphos_core())
  );

-- --- compliance_rules --------------------------------------------------------
-- Tabla de referencia: lectura para cualquier usuario autenticado; solo el
-- equipo interno de MORPHOS la mantiene (service_role).

create policy compliance_rules_select_all on public.compliance_rules
  for select to authenticated
  using (true);

-- --- compliance_alerts -------------------------------------------------------

create policy compliance_alerts_select on public.compliance_alerts
  for select to authenticated
  using (
    (select private.manages_company(company_id))
    or (select private.is_morphos_core())
  );

create policy compliance_alerts_update on public.compliance_alerts
  for update to authenticated
  using (
    (select private.manages_company(company_id))
    or (select private.is_morphos_core())
  )
  with check (
    (select private.manages_company(company_id))
    or (select private.is_morphos_core())
  );

-- --- modification_requests (§3.5) --------------------------------------------
-- Solo el owner solicita modificar un registro ya confirmado. El usuario
-- afectado puede ver la solicitud que le toca: es lo que hace util el rastro
-- si hay disputa.

create policy modification_requests_select on public.modification_requests
  for select to authenticated
  using (
    exists (
      select 1
      from public.ledger_entries le
      where le.id = ledger_entry_id
        and (
          le.origin_profile_id = (select private.app_profile_id())
          or (select private.is_company_owner(le.company_id))
          or (select private.is_morphos_core())
        )
    )
  );

create policy modification_requests_insert on public.modification_requests
  for insert to authenticated
  with check (
    requested_by = (select private.app_profile_id())
    and (
      exists (
        select 1
        from public.ledger_entries le
        where le.id = ledger_entry_id
          and (select private.is_company_owner(le.company_id))
      )
      or (select private.is_morphos_core())
    )
  );

-- ============================================================================
-- 4. Vistas
-- ============================================================================
-- security_invoker: sin esto la vista ignoraria RLS y expondria el saldo de
-- todo el mundo. El saldo es por pertenencia (§2.1): dos empresas de la misma
-- persona nunca suman juntas.

create view public.v_member_balance
with (security_invoker = true) as
select
  le.origin_member_id as member_id,
  le.company_id,
  le.period_ref,
  sum(le.amount) filter (where le.status = 'confirmado') as confirmed_balance,
  sum(le.amount) filter (where le.status = 'pendiente') as pending_balance
from public.ledger_entries le
where le.origin_member_id is not null
group by le.origin_member_id, le.company_id, le.period_ref;

-- Cobros y gastos por obra del dashboard (§4.1, bloques 5 y 6). Solo cuenta lo
-- confirmado, como exige §4.2.
create view public.v_work_site_totals
with (security_invoker = true) as
select
  le.company_id,
  le.work_site_id,
  le.period_ref,
  sum(le.amount) filter (
    where le.status = 'confirmado' and le.type in ('venta', 'afiliacion')
  ) as income,
  sum(le.amount) filter (
    where le.status = 'confirmado'
      and le.type in ('work_full_day', 'work_half_day', 'extra', 'deduccion')
  ) as labour_cost
from public.ledger_entries le
where le.scope = 'company'
group by le.company_id, le.work_site_id, le.period_ref;

-- ============================================================================
-- 5. Exposicion via Data API
-- ============================================================================
-- RLS decide que filas se ven; estos grants deciden si la tabla es alcanzable
-- del todo. anon no recibe nada: todo el acceso exige sesion.

grant select, update on public.profiles to authenticated;
grant select, insert, update on public.companies to authenticated;
grant select, insert, update on public.company_members to authenticated;
grant select, insert, update, delete on public.work_sites to authenticated;
grant select, insert, delete on public.admin_work_sites to authenticated;
grant select, insert, update, delete on public.assigned_shifts to authenticated;
grant select, insert, update on public.ledger_entries to authenticated;
grant select, insert, update on public.checkin_events to authenticated;
grant select on public.compliance_rules to authenticated;
grant select, update on public.compliance_alerts to authenticated;
grant select, insert on public.modification_requests to authenticated;
grant select on public.v_member_balance to authenticated;
grant select on public.v_work_site_totals to authenticated;
