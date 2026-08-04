-- Arranque del onboarding: crear la empresa y la fila de owner cuando el
-- usuario todavia no existe en public.users, sin abrir un agujero en las
-- policies de INSERT.
--
-- Vive en `public` porque tiene que ser invocable via /rest/v1/rpc/. Eso es
-- intencional, y por eso lleva sus propias guardas adentro: exige sesion,
-- impide que una cuenta que ya pertenece a una empresa cree otra, y nunca
-- acepta un user_id por parametro (la identidad sale siempre de auth.uid()).

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
  v_auth_uid uuid := (select auth.uid());
  v_company_id uuid;
  v_referral_code text;
  v_has_rules boolean;
  v_attempts integer := 0;
begin
  if v_auth_uid is null then
    raise exception 'Se requiere una sesion activa para crear una empresa.'
      using errcode = 'insufficient_privilege';
  end if;

  -- Una cuenta arranca una sola vez.
  if exists (select 1 from public.users where auth_user_id = v_auth_uid) then
    raise exception 'Esta cuenta ya pertenece a una empresa.'
      using errcode = 'unique_violation';
  end if;

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

  insert into public.users (
    auth_user_id, company_id, full_name, email, role, profile_type
  ) values (
    v_auth_uid,
    v_company_id,
    p_owner_full_name,
    (select email from auth.users where id = v_auth_uid),
    'owner',
    'sin_horario'
  );

  return v_company_id;
end;
$$;

revoke execute on function public.bootstrap_company(
  text, text, text, text, text, text, text, text[], text
) from public, anon;

grant execute on function public.bootstrap_company(
  text, text, text, text, text, text, text, text[], text
) to authenticated;
