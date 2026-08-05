-- MORPHOS — identidad, login y gestion de usuarios (§2.1, §3.1, §3.3, §3.4)
--
-- Estas funciones viven en `public` porque tienen que ser invocables via
-- /rest/v1/rpc/. Es intencional, y por eso cada una lleva sus guardas adentro:
-- exigen sesion, resuelven la identidad del llamante con auth.uid() (nunca la
-- aceptan por parametro) y comprueban el rol en la empresa antes de escribir.
--
-- Leer o editar el equipo no necesita funcion: se hace directo contra
-- public.company_members, donde las policies ya deciden.

-- ============================================================================
-- 1. ensure_profile — el puente entre el login y el modelo (§3.4)
-- ============================================================================
-- Se llama justo despues de iniciar sesion, siempre. Garantiza la invariante
-- que hace posible el multiempresa: una persona, un solo perfil.
--
--   1. Si la cuenta ya tiene perfil, lo devuelve.
--   2. Si alguien la invito antes (perfil con ese correo y sin cuenta), lo
--      reclama. Asi la persona entra ya con sus pertenencias puestas, incluso
--      si la invitaron desde varias empresas distintas.
--   3. Si no, crea el perfil. Todavia sin empresa: quien llega sin invitacion
--      va al onboarding a crear la suya.
--
-- Es la pieza que evita el problema de raiz: el login nunca crea una identidad
-- nueva para alguien que ya existe, y ninguna pertenencia queda huerfana.

create or replace function public.ensure_profile()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := (select auth.uid());
  v_email text;
  v_full_name text;
  v_profile_id uuid;
begin
  if v_auth_uid is null then
    raise exception 'Se requiere una sesion activa.'
      using errcode = 'insufficient_privilege';
  end if;

  select id into v_profile_id
  from public.profiles
  where auth_user_id = v_auth_uid;

  if v_profile_id is not null then
    return v_profile_id;
  end if;

  select email, coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name')
  into v_email, v_full_name
  from auth.users
  where id = v_auth_uid;

  if v_email is null then
    raise exception 'La cuenta no tiene correo asociado.'
      using errcode = 'check_violation';
  end if;

  -- Invitacion pendiente: el perfil ya existe, solo le falta la cuenta.
  update public.profiles
  set auth_user_id = v_auth_uid
  where lower(email) = lower(v_email)
    and auth_user_id is null
  returning id into v_profile_id;

  if v_profile_id is not null then
    return v_profile_id;
  end if;

  insert into public.profiles (auth_user_id, full_name, email)
  values (v_auth_uid, coalesce(nullif(v_full_name, ''), split_part(v_email, '@', 1)), lower(v_email))
  returning id into v_profile_id;

  return v_profile_id;
end;
$$;

-- ============================================================================
-- 2. bootstrap_company — crear una empresa y quedarse como owner
-- ============================================================================
-- Ya no es "el alta de la cuenta" sino "crear una empresa mas": §2.1 admite que
-- la misma persona tenga varias. Lo unico que se rechaza es repetir pertenencia
-- en una empresa donde ya se esta.

create or replace function public.bootstrap_company(
  p_company_name text,
  p_owner_full_name text,
  p_country text,
  p_region text,
  p_city text,
  p_industry_category text,
  p_industry_other_note text,
  p_business_need text[],
  p_referred_by_code text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := public.ensure_profile();
  v_company_id uuid;
  v_referral_code text;
  v_has_rules boolean;
  v_attempts integer := 0;
begin
  loop
    v_attempts := v_attempts + 1;
    v_referral_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1 from public.companies where referral_code = v_referral_code
    );
    if v_attempts > 10 then
      raise exception 'No se pudo generar un codigo de referido unico.';
    end if;
  end loop;

  -- Sin reglas cargadas para la jurisdiccion, la empresa se crea igual pero
  -- queda marcada como pendiente de compliance (no bloquea el onboarding).
  select exists (
    select 1
    from public.compliance_rules
    where jurisdiction = p_country || '-' || p_region
      and effective_from <= current_date
  ) into v_has_rules;

  insert into public.companies (
    name, country, region, city,
    industry_category, industry_other_note,
    business_need, referral_code, referred_by_code,
    compliance_pending
  ) values (
    p_company_name, p_country, p_region, p_city,
    p_industry_category, p_industry_other_note,
    coalesce(p_business_need, '{}'), v_referral_code, p_referred_by_code,
    not v_has_rules
  ) returning id into v_company_id;

  -- Quien crea la empresa es su titular de suscripcion (§2.1).
  insert into public.company_members (
    company_id, profile_id, role, profile_type, is_billing_owner
  ) values (
    v_company_id, v_profile_id, 'owner', 'sin_horario', true
  );

  -- El nombre solo se completa si el perfil aun no tenia uno propio.
  update public.profiles
  set full_name = p_owner_full_name
  where id = v_profile_id
    and p_owner_full_name is not null
    and (full_name is null or full_name = '');

  return v_company_id;
end;
$$;

-- ============================================================================
-- 3. invite_team_member — el owner suma a alguien a su empresa
-- ============================================================================
-- Si el correo ya tiene perfil (porque la persona usa MORPHOS en otra empresa,
-- o porque ya la invitaron), se reutiliza: la pertenencia nueva se cuelga del
-- mismo perfil. Eso es exactamente lo que hace que el multiempresa funcione sin
-- que la persona tenga que registrarse dos veces.

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
  if not (select private.is_company_owner(p_company_id)) then
    raise exception 'Solo el dueno de la empresa puede dar de alta al equipo.'
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

  select id into v_profile_id
  from public.profiles
  where lower(email) = lower(p_email);

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

-- ============================================================================
-- 4. set_admin_work_sites — que obras gestiona un administrador (§3.1, §5.10)
-- ============================================================================
-- Reemplaza la asignacion completa en una sola llamada: es como se comporta un
-- selector multiple en pantalla, y evita quedarse a medias entre dos escrituras.

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
  from public.company_members
  where id = p_member_id;

  if v_company_id is null then
    raise exception 'Esa pertenencia no existe.' using errcode = 'no_data_found';
  end if;

  if not (select private.is_company_owner(v_company_id)) then
    raise exception 'Solo el dueno de la empresa asigna obras a un administrador.'
      using errcode = 'insufficient_privilege';
  end if;

  if v_role is distinct from 'administrador' then
    raise exception 'Solo un administrador puede tener obras asignadas.'
      using errcode = 'check_violation';
  end if;

  -- La pertenencia del propio owner en esa empresa: es quien firma la asignacion.
  select m.id into v_actor_member_id
  from public.company_members m
  where m.company_id = v_company_id
    and m.profile_id = (select private.app_profile_id());

  delete from public.admin_work_sites
  where member_id = p_member_id
    and (p_work_site_ids is null or work_site_id <> all (p_work_site_ids));

  -- Cualquier obra ajena a la empresa se descarta aqui; el trigger de
  -- admin_work_sites lo volveria a rechazar de todos modos.
  insert into public.admin_work_sites (company_id, member_id, work_site_id, assigned_by)
  select v_company_id, p_member_id, ws.id, v_actor_member_id
  from public.work_sites ws
  where ws.company_id = v_company_id
    and ws.id = any (coalesce(p_work_site_ids, '{}'::uuid[]))
  on conflict (member_id, work_site_id) do nothing;

  select count(*) into v_assigned
  from public.admin_work_sites
  where member_id = p_member_id;

  return v_assigned;
end;
$$;

-- ============================================================================
-- 5. Permisos de ejecucion
-- ============================================================================

revoke execute on function public.ensure_profile() from public, anon;
revoke execute on function public.bootstrap_company(
  text, text, text, text, text, text, text, text[], text
) from public, anon;
revoke execute on function public.invite_team_member(
  uuid, text, text, text, numeric, numeric, text
) from public, anon;
revoke execute on function public.set_admin_work_sites(uuid, uuid[]) from public, anon;

grant execute on function public.ensure_profile() to authenticated;
grant execute on function public.bootstrap_company(
  text, text, text, text, text, text, text, text[], text
) to authenticated;
grant execute on function public.invite_team_member(
  uuid, text, text, text, numeric, numeric, text
) to authenticated;
grant execute on function public.set_admin_work_sites(uuid, uuid[]) to authenticated;
