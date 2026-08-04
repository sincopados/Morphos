-- MORPHOS — esquema inicial (Fase 0.5 Workforce)
--
-- Ver CONTEXT.md para el glosario del dominio y docs/adr/ para las decisiones
-- que dan forma a este esquema:
--   ADR-0001 — referidos viven en ledger_entries, no en una tabla aparte
--   ADR-0002 — check-in con foto de llegada/salida en vez de QR diario
--   ADR-0003 — turno asignado por dia (assigned_shifts), no jornada fija
--   ADR-0004 — bloqueo de check-in por rechazos acumulados
--
-- Principio de diseno #0 de la spec: un solo motor. Todo evento que genera
-- valor pasa por ledger_entries: se crea `pendiente`, la cuenta maestra lo
-- confirma, y ahi se acredita al saldo. No dupliques logica de confirmacion.

-- ============================================================================
-- 0. Esquema privado para helpers de RLS
-- ============================================================================

create schema if not exists private;

-- ============================================================================
-- 1. companies
-- ============================================================================

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text not null,
  region text not null,
  city text,

  -- Deriva la jurisdiccion que activa las filas de compliance_rules ("US-NY").
  jurisdiction text generated always as (country || '-' || region) stored,

  industry_category text not null check (industry_category in (
    'construccion', 'gastronomia', 'retail',
    'servicios_profesionales', 'belleza', 'otro'
  )),
  -- Nota libre que acompana a "otro". Sin efecto funcional: no clasifica ni
  -- precarga valores sugeridos (ver CONTEXT.md, "Industria Otro").
  industry_other_note text,

  business_need text[] not null default '{}',

  plan text not null default 'free' check (plan in ('free', 'basic', 'pro', 'enterprise')),

  referral_code text not null unique,
  referred_by_code text,

  -- Jurisdiccion sin fila activa en compliance_rules: no bloquea el onboarding,
  -- pero la empresa no recibe alertas hasta que el equipo interno la active.
  compliance_pending boolean not null default true,

  -- Habilita que morphos_core confirme en nombre de la empresa (regla #2).
  supervision_contracted boolean not null default false,
  supervision_contracted_at timestamptz,

  created_at timestamptz not null default now(),

  constraint companies_business_need_values
    check (business_need <@ array['gestion_personal', 'ventas', 'afiliados']::text[]),
  constraint companies_other_note_only_for_otro
    check (industry_other_note is null or industry_category = 'otro'),
  constraint companies_supervision_date_requires_contract
    check (supervision_contracted_at is null or supervision_contracted)
);

create index companies_jurisdiction_idx on public.companies (jurisdiction);
create index companies_referred_by_code_idx on public.companies (referred_by_code)
  where referred_by_code is not null;

-- ============================================================================
-- 2. users
-- ============================================================================
-- El dueno invita al equipo por nombre y rol antes de que existan cuentas
-- (Pantalla 7 del onboarding), asi que auth_user_id es nullable y se enlaza
-- cuando la persona acepta la invitacion.

create table public.users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users (id) on delete set null,
  company_id uuid references public.companies (id) on delete cascade,

  full_name text not null,
  email text,

  role text not null check (role in (
    'owner', 'admin_delegado', 'trabajador',
    'vendedor', 'afiliado', 'tutor', 'asesor',
    'morphos_core'
  )),

  -- con_horario usa check-in de jornada; sin_horario registra eventos de venta.
  profile_type text not null check (profile_type in ('con_horario', 'sin_horario')),

  full_day_value numeric(12, 2),
  half_day_value numeric(12, 2),

  pay_period text not null default 'semanal'
    check (pay_period in ('diario', 'semanal', 'mensual')),

  status text not null default 'activo' check (status in ('activo', 'inactivo')),

  -- ADR-0004: se activa al 3er rechazo acumulado; solo un admin lo revierte.
  checkin_blocked boolean not null default false,
  checkin_blocked_at timestamptz,

  created_at timestamptz not null default now(),

  -- tutor y morphos_core son roles de plataforma: nunca pertenecen a una empresa.
  constraint users_platform_roles_have_no_company
    check (role not in ('tutor', 'morphos_core') or company_id is null),
  -- Los roles internos de una empresa exigen pertenecer a una.
  constraint users_company_roles_require_company
    check (role not in ('owner', 'admin_delegado', 'trabajador') or company_id is not null),
  constraint users_blocked_date_requires_block
    check (checkin_blocked_at is null or checkin_blocked)
);

create index users_company_id_idx on public.users (company_id);
create index users_auth_user_id_idx on public.users (auth_user_id);

-- ============================================================================
-- 3. work_sites — sitio/obra (ADR-0002)
-- ============================================================================

create table public.work_sites (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null,
  address text not null,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  status text not null default 'activo' check (status in ('activo', 'inactivo')),
  created_at timestamptz not null default now()
);

create index work_sites_company_id_idx on public.work_sites (company_id);

-- ============================================================================
-- 4. assigned_shifts — turno asignado (ADR-0003)
-- ============================================================================
-- El dueno/admin define, por trabajador y por dia, que jornada se espera y en
-- que sitio. El trabajador no la elige: solo la confirma con fotos.

create table public.assigned_shifts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  work_site_id uuid references public.work_sites (id) on delete set null,

  shift_date date not null,
  jornada_type text not null check (jornada_type in ('work_full_day', 'work_half_day')),

  assigned_by uuid not null references public.users (id) on delete restrict,
  created_at timestamptz not null default now(),

  unique (user_id, shift_date)
);

create index assigned_shifts_company_date_idx on public.assigned_shifts (company_id, shift_date);
create index assigned_shifts_work_site_id_idx on public.assigned_shifts (work_site_id);
create index assigned_shifts_assigned_by_idx on public.assigned_shifts (assigned_by);

-- ============================================================================
-- 5. ledger_entries — el nucleo del sistema
-- ============================================================================

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),

  -- Null solo para eventos de plataforma (usuario sin empresa).
  company_id uuid references public.companies (id) on delete cascade,
  origin_user_id uuid not null references public.users (id) on delete restrict,

  -- Vincula un extra/deduccion a la jornada que lo origino.
  related_entry_id uuid references public.ledger_entries (id) on delete cascade,

  -- Derivado de la pertenencia a empresa del origin_user_id.
  scope text not null check (scope in ('platform', 'company')),

  type text not null check (type in (
    'work_full_day', 'work_half_day', 'extra', 'deduccion',
    'venta', 'afiliacion', 'referido'
  )),

  amount numeric(12, 2) not null,

  -- Solo informativo, para las alertas de compliance. Nunca entra al calculo
  -- del pago: eso lo determina el turno asignado.
  hours_reported numeric(5, 2),

  status text not null default 'pendiente'
    check (status in ('pendiente', 'confirmado', 'rechazado')),

  confirmed_by uuid references public.users (id) on delete restrict,
  confirmed_at timestamptz,
  -- Obligatorio al rechazar: un rechazo afecta el pago de alguien.
  rejection_reason text,

  -- El saldo diario es la unidad base: siempre la fecha del dia, nunca semana
  -- ni mes. pay_period solo cambia como se agrupan estos dias al mostrarlo.
  period_ref date not null,

  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  -- Regla no-negociable #1: quien genera el registro nunca puede confirmarlo.
  constraint ledger_entries_no_self_confirm
    check (confirmed_by is null or confirmed_by <> origin_user_id),
  constraint ledger_entries_scope_matches_company
    check (
      (scope = 'company' and company_id is not null)
      or (scope = 'platform' and company_id is null)
    ),
  constraint ledger_entries_confirmed_fields
    check ((status = 'confirmado') = (confirmed_by is not null and confirmed_at is not null)),
  constraint ledger_entries_rejection_needs_reason
    check (status <> 'rechazado' or rejection_reason is not null),
  -- ADR-0001: los referidos son siempre acreditacion de plataforma.
  constraint ledger_entries_referido_is_platform
    check (type <> 'referido' or scope = 'platform'),
  constraint ledger_entries_related_only_for_adjustments
    check (related_entry_id is null or type in ('extra', 'deduccion'))
);

create index ledger_entries_company_status_idx on public.ledger_entries (company_id, status);
create index ledger_entries_confirmed_by_idx on public.ledger_entries (confirmed_by);
create index ledger_entries_related_entry_id_idx on public.ledger_entries (related_entry_id);
-- Sirve la consulta de saldo: origen + estado + periodo.
create index ledger_entries_balance_idx
  on public.ledger_entries (origin_user_id, status, period_ref);

-- ============================================================================
-- 6. checkin_events — evidencia fotografica y horas reales (ADR-0002)
-- ============================================================================
-- Tabla separada a proposito: las horas reales de llegada/salida son visibles
-- solo para administracion. El trabajador escribe aqui pero no lee (ver RLS).

create table public.checkin_events (
  id uuid primary key default gen_random_uuid(),
  ledger_entry_id uuid not null unique references public.ledger_entries (id) on delete cascade,
  company_id uuid not null references public.companies (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  work_site_id uuid references public.work_sites (id) on delete set null,

  checkin_at timestamptz,
  checkin_photo_path text,
  checkin_latitude numeric(9, 6),
  checkin_longitude numeric(9, 6),

  checkout_at timestamptz,
  checkout_photo_path text,
  checkout_latitude numeric(9, 6),
  checkout_longitude numeric(9, 6),

  created_at timestamptz not null default now(),

  constraint checkin_events_checkout_after_checkin
    check (checkout_at is null or checkin_at is null or checkout_at >= checkin_at)
);

create index checkin_events_company_id_idx on public.checkin_events (company_id);
create index checkin_events_user_id_idx on public.checkin_events (user_id);
create index checkin_events_work_site_id_idx on public.checkin_events (work_site_id);

-- ============================================================================
-- 7. compliance_rules
-- ============================================================================
-- Reglas de referencia. Informativas, jamas bloqueantes (regla #3).
-- Se versionan por effective_from: las reglas cambian, no se sobrescriben.

create table public.compliance_rules (
  id uuid primary key default gen_random_uuid(),
  jurisdiction text not null,
  rule_type text not null check (rule_type in (
    'min_wage', 'overtime_day', 'overtime_night', 'sunday_holiday'
  )),
  currency text not null,
  base_value numeric(12, 2) not null,
  threshold_hours_week numeric(5, 2),
  surcharge_percentage numeric(6, 2),
  effective_from date not null,
  source_url text,
  created_at timestamptz not null default now(),

  unique (jurisdiction, rule_type, effective_from)
);

create index compliance_rules_lookup_idx
  on public.compliance_rules (jurisdiction, rule_type, effective_from desc);

-- ============================================================================
-- 8. compliance_alerts
-- ============================================================================
-- El registro de que se informo es lo que protege legalmente.

create table public.compliance_alerts (
  id uuid primary key default gen_random_uuid(),
  ledger_entry_id uuid references public.ledger_entries (id) on delete cascade,
  company_id uuid not null references public.companies (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  rule_id uuid not null references public.compliance_rules (id) on delete restrict,

  implied_hourly_rate numeric(12, 2),
  shown_to uuid references public.users (id) on delete set null,
  shown_at timestamptz,
  acknowledged boolean not null default false,

  created_at timestamptz not null default now()
);

create index compliance_alerts_ledger_entry_id_idx on public.compliance_alerts (ledger_entry_id);
create index compliance_alerts_company_id_idx on public.compliance_alerts (company_id);
create index compliance_alerts_user_id_idx on public.compliance_alerts (user_id);
create index compliance_alerts_rule_id_idx on public.compliance_alerts (rule_id);
create index compliance_alerts_shown_to_idx on public.compliance_alerts (shown_to);

-- ============================================================================
-- 9. modification_requests
-- ============================================================================
-- Auditoria, no gobernanza de doble aprobacion: deja rastro inmutable de que
-- se rompio la ventana de 72h y por que.

create table public.modification_requests (
  id uuid primary key default gen_random_uuid(),
  ledger_entry_id uuid not null references public.ledger_entries (id) on delete cascade,

  original_snapshot jsonb not null,
  new_values jsonb not null,

  within_72h_window boolean not null,
  reason text,

  requested_by uuid not null references public.users (id) on delete restrict,
  approved_by uuid references public.users (id) on delete restrict,
  status text not null default 'pendiente'
    check (status in ('pendiente', 'aprobado', 'rechazado')),

  created_at timestamptz not null default now(),

  -- Fuera de la ventana de 72h el motivo es obligatorio.
  constraint modification_requests_reason_outside_window
    check (within_72h_window or reason is not null)
);

create index modification_requests_ledger_entry_id_idx
  on public.modification_requests (ledger_entry_id);
create index modification_requests_requested_by_idx on public.modification_requests (requested_by);
create index modification_requests_approved_by_idx on public.modification_requests (approved_by);

-- ============================================================================
-- 10. Helpers de RLS
-- ============================================================================
-- SECURITY DEFINER para poder leer public.users sin recursion de politicas.
-- Cada funcion resuelve la identidad del llamante via auth.uid(): nunca
-- aceptan un user_id arbitrario como parametro de identidad.

create or replace function private.app_user_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from public.users u
  where u.auth_user_id = (select auth.uid())
  limit 1;
$$;

create or replace function private.app_company_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.company_id
  from public.users u
  where u.auth_user_id = (select auth.uid())
  limit 1;
$$;

-- Es owner o admin_delegado activo de la empresa indicada.
create or replace function private.is_company_admin(target_company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users u
    where u.auth_user_id = (select auth.uid())
      and u.status = 'activo'
      and u.company_id = target_company
      and u.role in ('owner', 'admin_delegado')
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
  select exists (
    select 1
    from public.users u
    where u.auth_user_id = (select auth.uid())
      and u.status = 'activo'
      and (
        (u.role in ('owner', 'admin_delegado') and u.company_id = target_company)
        or (
          u.role = 'morphos_core'
          and exists (
            select 1
            from public.companies c
            where c.id = target_company
              and c.supervision_contracted
          )
        )
      )
  );
$$;

-- Las tres solo exponen el contexto del propio llamante, asi que authenticated
-- puede ejecutarlas; anon no tiene nada que hacer aqui.
revoke execute on function private.app_user_id() from public, anon;
revoke execute on function private.app_company_id() from public, anon;
revoke execute on function private.is_company_admin(uuid) from public, anon;
revoke execute on function private.can_confirm_for(uuid) from public, anon;

grant usage on schema private to authenticated;
grant execute on function private.app_user_id() to authenticated;
grant execute on function private.app_company_id() to authenticated;
grant execute on function private.is_company_admin(uuid) to authenticated;
grant execute on function private.can_confirm_for(uuid) to authenticated;

-- ============================================================================
-- 11. Triggers de reglas de negocio
-- ============================================================================

-- ADR-0004: al 3er rechazo acumulado se bloquea el check-in del trabajador.
-- La notificacion al admin en el 2do rechazo vive en la capa de aplicacion.
create or replace function public.handle_ledger_rejection()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rejection_count integer;
begin
  if new.status = 'rechazado' and old.status is distinct from 'rechazado' then
    select count(*)
    into rejection_count
    from public.ledger_entries
    where origin_user_id = new.origin_user_id
      and status = 'rechazado';

    if rejection_count >= 3 then
      update public.users
      set checkin_blocked = true,
          checkin_blocked_at = now()
      where id = new.origin_user_id
        and not checkin_blocked;
    end if;
  end if;

  return new;
end;
$$;

create trigger ledger_entries_rejection_block
after update of status on public.ledger_entries
for each row
execute function public.handle_ledger_rejection();

-- Un trabajador bloqueado no puede registrar jornadas hasta que un admin lo
-- desbloquee.
create or replace function public.enforce_checkin_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.type in ('work_full_day', 'work_half_day')
     and exists (
       select 1
       from public.users u
       where u.id = new.origin_user_id
         and u.checkin_blocked
     )
  then
    raise exception 'El check-in de este trabajador esta bloqueado. Un administrador debe desbloquearlo.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger ledger_entries_enforce_checkin_block
before insert on public.ledger_entries
for each row
execute function public.enforce_checkin_block();

-- Calcula la ventana de 72h a partir de la confirmacion del registro original.
create or replace function public.set_modification_window()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  entry_confirmed_at timestamptz;
begin
  select confirmed_at
  into entry_confirmed_at
  from public.ledger_entries
  where id = new.ledger_entry_id;

  new.within_72h_window := entry_confirmed_at is not null
    and now() - entry_confirmed_at <= interval '72 hours';

  return new;
end;
$$;

create trigger modification_requests_set_window
before insert on public.modification_requests
for each row
execute function public.set_modification_window();

-- ============================================================================
-- 12. Row Level Security
-- ============================================================================

alter table public.companies enable row level security;
alter table public.users enable row level security;
alter table public.work_sites enable row level security;
alter table public.assigned_shifts enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.checkin_events enable row level security;
alter table public.compliance_rules enable row level security;
alter table public.compliance_alerts enable row level security;
alter table public.modification_requests enable row level security;

-- --- companies --------------------------------------------------------------

create policy companies_select_own on public.companies
  for select to authenticated
  using (id = (select private.app_company_id()));

create policy companies_update_admin on public.companies
  for update to authenticated
  using ((select private.is_company_admin(id)))
  with check ((select private.is_company_admin(id)));

-- --- users ------------------------------------------------------------------

create policy users_select_self on public.users
  for select to authenticated
  using (auth_user_id = (select auth.uid()));

create policy users_select_company_admin on public.users
  for select to authenticated
  using ((select private.is_company_admin(company_id)));

create policy users_insert_company_admin on public.users
  for insert to authenticated
  with check ((select private.is_company_admin(company_id)));

create policy users_update_company_admin on public.users
  for update to authenticated
  using ((select private.is_company_admin(company_id)))
  with check ((select private.is_company_admin(company_id)));

-- --- work_sites -------------------------------------------------------------

create policy work_sites_select_company on public.work_sites
  for select to authenticated
  using (company_id = (select private.app_company_id()));

create policy work_sites_write_admin on public.work_sites
  for all to authenticated
  using ((select private.is_company_admin(company_id)))
  with check ((select private.is_company_admin(company_id)));

-- --- assigned_shifts --------------------------------------------------------
-- El trabajador ve su turno; solo administracion lo define.

create policy assigned_shifts_select_own on public.assigned_shifts
  for select to authenticated
  using (user_id = (select private.app_user_id()));

create policy assigned_shifts_select_admin on public.assigned_shifts
  for select to authenticated
  using ((select private.is_company_admin(company_id)));

create policy assigned_shifts_write_admin on public.assigned_shifts
  for all to authenticated
  using ((select private.is_company_admin(company_id)))
  with check ((select private.is_company_admin(company_id)));

-- --- ledger_entries ---------------------------------------------------------

create policy ledger_entries_select_own on public.ledger_entries
  for select to authenticated
  using (origin_user_id = (select private.app_user_id()));

create policy ledger_entries_select_company_admin on public.ledger_entries
  for select to authenticated
  using ((select private.is_company_admin(company_id)));

-- Cada quien registra lo suyo, siempre como pendiente.
create policy ledger_entries_insert_own on public.ledger_entries
  for insert to authenticated
  with check (
    origin_user_id = (select private.app_user_id())
    and status = 'pendiente'
    and confirmed_by is null
  );

-- Confirmar o rechazar: solo la cuenta maestra (o supervision contratada).
create policy ledger_entries_confirm on public.ledger_entries
  for update to authenticated
  using ((select private.can_confirm_for(company_id)))
  with check ((select private.can_confirm_for(company_id)));

-- --- checkin_events ---------------------------------------------------------
-- El trabajador escribe su evidencia pero no puede leerla: las horas reales
-- son informacion de administracion.

create policy checkin_events_insert_own on public.checkin_events
  for insert to authenticated
  with check (user_id = (select private.app_user_id()));

create policy checkin_events_update_own on public.checkin_events
  for update to authenticated
  using (user_id = (select private.app_user_id()))
  with check (user_id = (select private.app_user_id()));

create policy checkin_events_select_admin on public.checkin_events
  for select to authenticated
  using ((select private.is_company_admin(company_id)));

-- --- compliance_rules -------------------------------------------------------
-- Tabla de referencia: lectura para cualquier usuario autenticado; solo el
-- equipo interno de MORPHOS la mantiene (service_role).

create policy compliance_rules_select_all on public.compliance_rules
  for select to authenticated
  using (true);

-- --- compliance_alerts ------------------------------------------------------

create policy compliance_alerts_select_admin on public.compliance_alerts
  for select to authenticated
  using ((select private.is_company_admin(company_id)));

create policy compliance_alerts_update_admin on public.compliance_alerts
  for update to authenticated
  using ((select private.is_company_admin(company_id)))
  with check ((select private.is_company_admin(company_id)));

-- --- modification_requests --------------------------------------------------
-- Solo el owner solicita modificar un registro ya confirmado.

create policy modification_requests_select_admin on public.modification_requests
  for select to authenticated
  using (
    exists (
      select 1
      from public.ledger_entries le
      where le.id = ledger_entry_id
        and (select private.is_company_admin(le.company_id))
    )
  );

create policy modification_requests_insert_owner on public.modification_requests
  for insert to authenticated
  with check (
    requested_by = (select private.app_user_id())
    and exists (
      select 1
      from public.users u
      where u.id = requested_by
        and u.role = 'owner'
    )
  );

-- ============================================================================
-- 13. Vistas
-- ============================================================================
-- security_invoker: sin esto la vista ignoraria RLS y expondria el saldo de
-- todo el mundo.

create view public.v_user_balance
with (security_invoker = true) as
select
  le.origin_user_id as user_id,
  le.company_id,
  le.period_ref,
  sum(le.amount) filter (where le.status = 'confirmado') as confirmed_balance,
  sum(le.amount) filter (where le.status = 'pendiente') as pending_balance
from public.ledger_entries le
group by le.origin_user_id, le.company_id, le.period_ref;

-- ============================================================================
-- 14. Exposicion via Data API
-- ============================================================================
-- RLS decide que filas se ven; estos grants deciden si la tabla es alcanzable
-- del todo. Explicitos para no depender de la configuracion de Data API del
-- proyecto. anon no recibe nada: todo el acceso exige sesion.

grant select, insert, update on public.companies to authenticated;
grant select, insert, update on public.users to authenticated;
grant select, insert, update, delete on public.work_sites to authenticated;
grant select, insert, update, delete on public.assigned_shifts to authenticated;
grant select, insert, update on public.ledger_entries to authenticated;
grant select, insert, update on public.checkin_events to authenticated;
grant select on public.compliance_rules to authenticated;
grant select, update on public.compliance_alerts to authenticated;
grant select, insert on public.modification_requests to authenticated;
grant select on public.v_user_balance to authenticated;
