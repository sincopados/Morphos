-- MORPHOS — esquema base
--
-- Baseline unico (la base se vacio antes de aplicarlo). Los roles y su alcance
-- salen de CONTEXT.md §2.1, §3.1 y §5.10, y las decisiones de docs/adr/:
--   ADR-0001 — referidos viven en ledger_entries, no en una tabla aparte
--   ADR-0002 — check-in con foto de llegada/salida en vez de QR diario
--   ADR-0003 — turno asignado por dia (assigned_shifts), no jornada fija
--   ADR-0004 — bloqueo de check-in por rechazos acumulados
--
-- Decision estructural (§2.1): la identidad de una persona y su pertenencia a
-- una empresa son cosas distintas.
--
--   profiles        — quien eres. Una fila por persona, enlazada a auth.users.
--   company_members — que eres en cada empresa. Una fila por (empresa, persona),
--                     y es donde vive el rol, la tarifa, el saldo y el estado.
--
-- Por eso el rol es un atributo de la pertenencia y no de la persona: alguien
-- puede ser `owner` en su empresa y `trabajador` en otra. Todo lo que antes
-- apuntaba a un "usuario" apunta ahora a una pertenencia (`member_id`), salvo
-- lo que es genuinamente de la persona (quien confirmo, quien pidio modificar).

create schema if not exists private;

-- ============================================================================
-- 1. profiles — identidad
-- ============================================================================
-- auth_user_id es nullable a proposito: el owner invita por nombre y correo
-- antes de que exista la cuenta (Pantalla 7 del onboarding). La fila nace como
-- invitacion y se enlaza al entrar por primera vez con ese correo.
--
-- platform_role es para los roles de plataforma de §3.1/§3.2, que no pertenecen
-- a ninguna empresa: morphos_core (soporte), tutor y asesor.

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users (id) on delete set null,

  full_name text not null,
  email text,

  platform_role text check (platform_role in ('morphos_core', 'tutor', 'asesor')),

  created_at timestamptz not null default now()
);

-- El correo es la llave con la que una invitacion encuentra a su persona, y lo
-- que permite que dos empresas distintas inviten a la misma. Sin unicidad, un
-- segundo perfil con el mismo correo partiria a la persona en dos.
create unique index profiles_email_idx on public.profiles (lower(email))
  where email is not null;
create index profiles_auth_user_id_idx on public.profiles (auth_user_id);

-- ============================================================================
-- 2. companies
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
-- 3. company_members — la pertenencia (§2.1, §3.1, §3.3)
-- ============================================================================
-- Una fila por persona y empresa. Todo lo que depende de la empresa vive aqui,
-- no en profiles: el rol, el perfil horario, las tarifas, el estado y el
-- bloqueo de check-in. Dos pertenencias de la misma persona no comparten nada.

create table public.company_members (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,

  -- §3.1. `administrador` sustituye al antiguo `admin_delegado`: su alcance no
  -- es la empresa entera, son las obras que el owner le asigne.
  role text not null check (role in (
    'owner', 'administrador', 'trabajador', 'vendedor', 'afiliado'
  )),

  -- con_horario usa check-in de jornada; sin_horario registra eventos.
  profile_type text not null check (profile_type in ('con_horario', 'sin_horario')),

  full_day_value numeric(12, 2),
  half_day_value numeric(12, 2),

  pay_period text not null default 'semanal'
    check (pay_period in ('diario', 'semanal', 'mensual')),

  status text not null default 'activo' check (status in ('activo', 'inactivo')),

  -- ADR-0004: se activa al 3er rechazo acumulado; solo un admin lo revierte.
  checkin_blocked boolean not null default false,
  checkin_blocked_at timestamptz,

  -- §2.1: varios owner por empresa (socios), pero uno solo paga.
  is_billing_owner boolean not null default false,

  created_at timestamptz not null default now(),

  unique (company_id, profile_id),

  -- §3.2: solo el trabajador ficha por bloques de tiempo.
  constraint members_profile_matches_role
    check ((role = 'trabajador') = (profile_type = 'con_horario')),
  constraint members_billing_owner_is_owner
    check (not is_billing_owner or role = 'owner'),
  constraint members_blocked_date_requires_block
    check (checkin_blocked_at is null or checkin_blocked)
);

create index company_members_company_role_idx on public.company_members (company_id, role);
create index company_members_profile_id_idx on public.company_members (profile_id);

-- Un solo titular de suscripcion por empresa.
create unique index company_members_billing_owner_idx
  on public.company_members (company_id)
  where is_billing_owner;

-- ============================================================================
-- 4. work_sites — obra / sitio (ADR-0002, §2.2)
-- ============================================================================

create table public.work_sites (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null,
  address text not null,
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  -- §2.2: solo las activas aparecen en los desgloses operativos del dashboard.
  status text not null default 'activa'
    check (status in ('activa', 'cerrada', 'archivada')),
  created_at timestamptz not null default now()
);

create index work_sites_company_id_idx on public.work_sites (company_id);

-- ============================================================================
-- 5. admin_work_sites — que obras gestiona cada administrador (§3.1, §5.10)
-- ============================================================================
-- Es lo que convierte a `administrador` en un rol acotado en vez de un segundo
-- owner: sin fila aqui, un administrador no alcanza ninguna obra.

create table public.admin_work_sites (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  member_id uuid not null references public.company_members (id) on delete cascade,
  work_site_id uuid not null references public.work_sites (id) on delete cascade,

  assigned_by uuid not null references public.company_members (id) on delete restrict,
  created_at timestamptz not null default now(),

  unique (member_id, work_site_id)
);

create index admin_work_sites_company_id_idx on public.admin_work_sites (company_id);
create index admin_work_sites_work_site_id_idx on public.admin_work_sites (work_site_id);
create index admin_work_sites_assigned_by_idx on public.admin_work_sites (assigned_by);

-- Solo un administrador puede tener obras asignadas: el owner ya las alcanza
-- todas, y a cualquier otro rol la asignacion no le daria ningun permiso.
create or replace function private.enforce_admin_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_member_company uuid;
  v_site_company uuid;
begin
  select role, company_id into v_role, v_member_company
  from public.company_members where id = new.member_id;

  if v_role is distinct from 'administrador' then
    raise exception 'Solo una pertenencia con rol administrador puede tener obras asignadas.'
      using errcode = 'check_violation';
  end if;

  select company_id into v_site_company
  from public.work_sites where id = new.work_site_id;

  -- La obra, la pertenencia y la asignacion tienen que ser de la misma
  -- empresa; si no, la asignacion seria una fuga entre empresas.
  if v_member_company is distinct from v_site_company
     or new.company_id is distinct from v_site_company then
    raise exception 'La obra y el administrador deben pertenecer a la misma empresa.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger admin_work_sites_enforce_role
before insert or update on public.admin_work_sites
for each row
execute function private.enforce_admin_assignment();

-- ============================================================================
-- 6. assigned_shifts — turno asignado (ADR-0003)
-- ============================================================================
-- El dueno/admin define, por trabajador y por dia, que jornada se espera y en
-- que obra. El trabajador no la elige: solo la confirma con fotos.

create table public.assigned_shifts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  member_id uuid not null references public.company_members (id) on delete cascade,
  work_site_id uuid references public.work_sites (id) on delete set null,

  shift_date date not null,
  jornada_type text not null check (jornada_type in ('work_full_day', 'work_half_day')),

  assigned_by uuid not null references public.company_members (id) on delete restrict,
  created_at timestamptz not null default now(),

  -- Un turno por persona y dia dentro de una empresa. Que sea por pertenencia
  -- y no por persona es lo que deja trabajar el mismo dia en dos empresas.
  unique (member_id, shift_date)
);

create index assigned_shifts_company_date_idx on public.assigned_shifts (company_id, shift_date);
create index assigned_shifts_work_site_id_idx on public.assigned_shifts (work_site_id);
create index assigned_shifts_assigned_by_idx on public.assigned_shifts (assigned_by);

-- ============================================================================
-- 7. ledger_entries — el nucleo del sistema
-- ============================================================================
-- origin_profile_id dice quien lo genero como persona; origin_member_id, con
-- que sombrero. Los eventos de plataforma (un referido) no tienen empresa ni
-- pertenencia, y por eso member es nullable.

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),

  -- Null solo para eventos de plataforma.
  company_id uuid references public.companies (id) on delete cascade,
  origin_profile_id uuid not null references public.profiles (id) on delete restrict,
  origin_member_id uuid references public.company_members (id) on delete restrict,

  -- La obra a la que se imputa. Null = "General / Empresa" (§2.2).
  work_site_id uuid references public.work_sites (id) on delete set null,

  -- Vincula un extra/deduccion a la jornada que lo origino.
  related_entry_id uuid references public.ledger_entries (id) on delete cascade,

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

  confirmed_by uuid references public.profiles (id) on delete restrict,
  confirmed_at timestamptz,
  -- Obligatorio al rechazar: un rechazo afecta el pago de alguien.
  rejection_reason text,

  -- El saldo diario es la unidad base: siempre la fecha del dia, nunca semana
  -- ni mes. pay_period solo cambia como se agrupan estos dias al mostrarlo.
  period_ref date not null,

  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  -- Regla no-negociable #1: quien genera el registro nunca puede confirmarlo.
  -- Se compara por persona, no por pertenencia: cambiar de sombrero dentro de
  -- la misma empresa no puede convertirte en tu propio confirmador.
  constraint ledger_entries_no_self_confirm
    check (confirmed_by is null or confirmed_by <> origin_profile_id),
  constraint ledger_entries_scope_matches_company
    check (
      (scope = 'company' and company_id is not null and origin_member_id is not null)
      or (scope = 'platform' and company_id is null and origin_member_id is null)
    ),
  constraint ledger_entries_site_only_for_company
    check (work_site_id is null or scope = 'company'),
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
create index ledger_entries_origin_profile_idx on public.ledger_entries (origin_profile_id);
-- Sirve los desgloses por obra del dashboard (§4.1).
create index ledger_entries_work_site_idx on public.ledger_entries (work_site_id, status);
-- Sirve la consulta de saldo: pertenencia + estado + periodo.
create index ledger_entries_balance_idx
  on public.ledger_entries (origin_member_id, status, period_ref);

-- ============================================================================
-- 8. checkin_events — evidencia fotografica y horas reales (ADR-0002)
-- ============================================================================
-- Tabla separada a proposito: las horas reales de llegada/salida son visibles
-- solo para administracion. El trabajador escribe aqui pero no lee (ver RLS).

create table public.checkin_events (
  id uuid primary key default gen_random_uuid(),
  ledger_entry_id uuid not null unique references public.ledger_entries (id) on delete cascade,
  company_id uuid not null references public.companies (id) on delete cascade,
  member_id uuid not null references public.company_members (id) on delete cascade,
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
create index checkin_events_member_id_idx on public.checkin_events (member_id);
create index checkin_events_work_site_id_idx on public.checkin_events (work_site_id);

-- ============================================================================
-- 9. compliance_rules
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
-- 10. compliance_alerts
-- ============================================================================
-- El registro de que se informo es lo que protege legalmente.

create table public.compliance_alerts (
  id uuid primary key default gen_random_uuid(),
  ledger_entry_id uuid references public.ledger_entries (id) on delete cascade,
  company_id uuid not null references public.companies (id) on delete cascade,
  member_id uuid not null references public.company_members (id) on delete cascade,
  rule_id uuid not null references public.compliance_rules (id) on delete restrict,

  implied_hourly_rate numeric(12, 2),
  shown_to uuid references public.company_members (id) on delete set null,
  shown_at timestamptz,
  acknowledged boolean not null default false,

  created_at timestamptz not null default now()
);

create index compliance_alerts_ledger_entry_id_idx on public.compliance_alerts (ledger_entry_id);
create index compliance_alerts_company_id_idx on public.compliance_alerts (company_id);
create index compliance_alerts_member_id_idx on public.compliance_alerts (member_id);
create index compliance_alerts_rule_id_idx on public.compliance_alerts (rule_id);
create index compliance_alerts_shown_to_idx on public.compliance_alerts (shown_to);

-- ============================================================================
-- 11. modification_requests (§3.5)
-- ============================================================================
-- Auditoria, no gobernanza de doble aprobacion: deja rastro inmutable de que
-- se rompio la ventana de 72h y por que. Va por persona: lo que importa es
-- quien firmo la solicitud.

create table public.modification_requests (
  id uuid primary key default gen_random_uuid(),
  ledger_entry_id uuid not null references public.ledger_entries (id) on delete cascade,

  original_snapshot jsonb not null,
  new_values jsonb not null,

  within_72h_window boolean not null,
  reason text,

  requested_by uuid not null references public.profiles (id) on delete restrict,
  approved_by uuid references public.profiles (id) on delete restrict,
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
-- 12. Triggers de reglas de negocio
-- ============================================================================

-- ADR-0004: al 3er rechazo acumulado se bloquea el check-in del trabajador.
-- El contador es por pertenencia, no por persona: un rechazo en una empresa no
-- puede bloquearte en otra.
create or replace function private.handle_ledger_rejection()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rejection_count integer;
begin
  if new.status = 'rechazado'
     and old.status is distinct from 'rechazado'
     and new.origin_member_id is not null
  then
    select count(*)
    into rejection_count
    from public.ledger_entries
    where origin_member_id = new.origin_member_id
      and status = 'rechazado';

    if rejection_count >= 3 then
      update public.company_members
      set checkin_blocked = true,
          checkin_blocked_at = now()
      where id = new.origin_member_id
        and not checkin_blocked;
    end if;
  end if;

  return new;
end;
$$;

create trigger ledger_entries_rejection_block
after update of status on public.ledger_entries
for each row
execute function private.handle_ledger_rejection();

-- Un trabajador bloqueado no puede registrar jornadas hasta que un admin lo
-- desbloquee, y solo en la empresa donde se le bloqueo.
create or replace function private.enforce_checkin_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.type in ('work_full_day', 'work_half_day')
     and exists (
       select 1
       from public.company_members m
       where m.id = new.origin_member_id
         and m.checkin_blocked
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
execute function private.enforce_checkin_block();

-- La pertenencia que origina un movimiento tiene que ser de la empresa del
-- movimiento y de la persona que figura como origen. Sin esto se podria
-- imputar trabajo de una empresa a otra.
create or replace function private.enforce_entry_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company uuid;
  v_profile uuid;
begin
  if new.origin_member_id is null then
    return new;
  end if;

  select company_id, profile_id into v_company, v_profile
  from public.company_members
  where id = new.origin_member_id;

  if v_company is distinct from new.company_id
     or v_profile is distinct from new.origin_profile_id then
    raise exception 'La pertenencia no corresponde a la empresa o a la persona del movimiento.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger ledger_entries_enforce_membership
before insert or update on public.ledger_entries
for each row
execute function private.enforce_entry_membership();

-- Calcula la ventana de 72h a partir de la confirmacion del registro original.
create or replace function private.set_modification_window()
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
execute function private.set_modification_window();

revoke execute on function private.enforce_admin_assignment() from public, anon, authenticated;
revoke execute on function private.handle_ledger_rejection() from public, anon, authenticated;
revoke execute on function private.enforce_checkin_block() from public, anon, authenticated;
revoke execute on function private.enforce_entry_membership() from public, anon, authenticated;
revoke execute on function private.set_modification_window() from public, anon, authenticated;
