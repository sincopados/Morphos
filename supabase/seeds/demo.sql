-- MORPHOS — datos de demo (NO aplicar en produccion)
--
-- No lo ejecuta `supabase db reset`: se aplica a mano cuando quieras un entorno
-- con algo dentro para probar pantallas.
--
--   psql "$DATABASE_URL" -f supabase/seeds/demo.sql
--
-- Monta el caso que motiva el modelo de pertenencias de §2.1: dos empresas y
-- una misma persona con rol distinto en cada una.
--
-- Ninguna fila toca auth.users. Los perfiles nacen sin `auth_user_id`, que es
-- exactamente la forma de una invitacion: al registrarte con uno de estos
-- correos, ensure_profile() reclama el perfil y entras con sus pertenencias ya
-- puestas. Asi se prueba el flujo real de invitacion, no un atajo.
--
-- Idempotente: si ya existe la empresa demo, no hace nada.

do $$
declare
  v_company_a uuid;
  v_company_b uuid;
  v_ana uuid;
  v_beto uuid;
  v_carla uuid;
  v_diego uuid;
  v_site_a1 uuid;
  v_site_a2 uuid;
  v_admin_member uuid;
  v_owner_member uuid;
begin
  if exists (select 1 from public.companies where referral_code = 'DEMO0001') then
    raise notice 'Los datos de demo ya estaban cargados; no se hace nada.';
    return;
  end if;

  -- --- Personas -------------------------------------------------------------
  -- Un solo perfil por persona, aunque trabaje en varias empresas (§2.1).

  insert into public.profiles (full_name, email)
  values ('Ana Duena', 'ana@demo.morphos.test')
  returning id into v_ana;

  insert into public.profiles (full_name, email)
  values ('Beto Administrador', 'beto@demo.morphos.test')
  returning id into v_beto;

  insert into public.profiles (full_name, email)
  values ('Carla Trabajadora', 'carla@demo.morphos.test')
  returning id into v_carla;

  insert into public.profiles (full_name, email)
  values ('Diego Vendedor', 'diego@demo.morphos.test')
  returning id into v_diego;

  -- --- Empresa A: constructora ---------------------------------------------

  insert into public.companies (
    name, country, region, city, industry_category,
    business_need, referral_code, compliance_pending
  ) values (
    'Constructora Demo', 'US', 'NY', 'New York', 'construccion',
    '{gestion_personal}', 'DEMO0001',
    not exists (
      select 1 from public.compliance_rules
      where jurisdiction = 'US-NY' and effective_from <= current_date
    )
  ) returning id into v_company_a;

  insert into public.company_members (company_id, profile_id, role, profile_type, is_billing_owner)
  values (v_company_a, v_ana, 'owner', 'sin_horario', true)
  returning id into v_owner_member;

  insert into public.company_members (company_id, profile_id, role, profile_type)
  values (v_company_a, v_beto, 'administrador', 'sin_horario')
  returning id into v_admin_member;

  insert into public.company_members (
    company_id, profile_id, role, profile_type, full_day_value, half_day_value
  ) values (v_company_a, v_carla, 'trabajador', 'con_horario', 200.00, 100.00);

  insert into public.company_members (company_id, profile_id, role, profile_type)
  values (v_company_a, v_diego, 'vendedor', 'sin_horario');

  -- --- Obras de la Empresa A ------------------------------------------------

  insert into public.work_sites (company_id, name, address)
  values (v_company_a, 'Obra Fieldmere', '186 Fieldmere Street, Elmont, NY 11003')
  returning id into v_site_a1;

  insert into public.work_sites (company_id, name, address)
  values (v_company_a, 'Obra Brooklyn', '55 Water Street, Brooklyn, NY 11201')
  returning id into v_site_a2;

  -- Beto solo gestiona una de las dos: es lo que hace visible en pantalla que
  -- `administrador` esta acotado a sus obras (§5.10). Con la otra obra no
  -- deberia poder hacer nada.
  insert into public.admin_work_sites (company_id, member_id, work_site_id, assigned_by)
  values (v_company_a, v_admin_member, v_site_a1, v_owner_member);

  -- --- Empresa B: la misma Ana, pero como trabajadora ----------------------
  -- Este es el caso que el modelo de pertenencias existe para soportar.

  insert into public.companies (
    name, country, region, city, industry_category,
    business_need, referral_code, compliance_pending
  ) values (
    'Reformas Demo', 'US', 'NY', 'New York', 'servicios_profesionales',
    '{gestion_personal}', 'DEMO0002',
    not exists (
      select 1 from public.compliance_rules
      where jurisdiction = 'US-NY' and effective_from <= current_date
    )
  ) returning id into v_company_b;

  insert into public.company_members (company_id, profile_id, role, profile_type, is_billing_owner)
  values (v_company_b, v_beto, 'owner', 'sin_horario', true);

  insert into public.company_members (
    company_id, profile_id, role, profile_type, full_day_value, half_day_value
  ) values (v_company_b, v_ana, 'trabajador', 'con_horario', 180.00, 90.00);

  raise notice 'Demo cargada. Registrate con ana@demo.morphos.test (owner en Constructora Demo, trabajadora en Reformas Demo) o beto@demo.morphos.test (administrador en una, owner en la otra).';
end;
$$;
