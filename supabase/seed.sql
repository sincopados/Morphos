-- MORPHOS — datos iniciales de despliegue
--
-- Se aplica solo con `supabase db reset` (o a mano tras crear el proyecto).
-- Contiene **datos de referencia**, no datos de demo: es lo minimo que la app
-- necesita para funcionar de verdad en cualquier entorno, incluido produccion.
-- Los datos de ejemplo (una empresa con equipo y obras) viven aparte, en
-- supabase/seeds/demo.sql, y nunca deben aplicarse en produccion.
--
-- Es idempotente: cada insert lleva su `on conflict do nothing` contra la clave
-- unica natural, asi que volver a ejecutarlo no duplica ni pisa nada.

-- ============================================================================
-- 1. compliance_rules — reglas de referencia por jurisdiccion
-- ============================================================================
-- Regla no-negociable #3: son informativas, jamas bloqueantes. MORPHOS avisa
-- de que un pago implica una tarifa por debajo del minimo, pero nunca impide
-- registrarlo. Lo que protege legalmente es el registro de que se informo.
--
-- Se versionan por effective_from: cuando una regla cambia se agrega una fila
-- nueva, nunca se edita la anterior. La consulta toma la vigente mas reciente.
--
-- Sin fila activa para su jurisdiccion, una empresa se crea igual pero queda
-- con compliance_pending = true y no recibe alertas hasta que el equipo interno
-- cargue la regla.
--
-- ATENCION: los importes de abajo son el punto de partida para el piloto y
-- salen del calendario publicado del salario minimo del estado de Nueva York.
-- Verificalos contra la fuente oficial antes de cada despliegue a produccion —
-- cambian por ley cada ano y por region dentro del mismo estado.

insert into public.compliance_rules (
  jurisdiction, rule_type, currency, base_value,
  threshold_hours_week, surcharge_percentage, effective_from, source_url
) values
  -- Nueva York (NYC, Long Island y Westchester). Es la jurisdiccion del piloto.
  (
    'US-NY', 'min_wage', 'USD', 17.00,
    null, null, date '2026-01-01',
    'https://dol.ny.gov/minimum-wage-0'
  ),
  -- FLSA: a partir de 40 h semanales, 1.5x sobre la tarifa ordinaria.
  (
    'US-NY', 'overtime_day', 'USD', 0,
    40, 50, date '2026-01-01',
    'https://www.dol.gov/agencies/whd/overtime'
  ),
  -- Ano anterior, para que un registro con fecha de 2025 se evalue con la
  -- regla que estaba vigente entonces y no con la de hoy.
  (
    'US-NY', 'min_wage', 'USD', 16.50,
    null, null, date '2025-01-01',
    'https://dol.ny.gov/minimum-wage-0'
  ),
  (
    'US-NY', 'overtime_day', 'USD', 0,
    40, 50, date '2025-01-01',
    'https://www.dol.gov/agencies/whd/overtime'
  )
on conflict (jurisdiction, rule_type, effective_from) do nothing;

-- ============================================================================
-- 2. Equipo interno de MORPHOS (§3.1, rol morphos_core)
-- ============================================================================
-- morphos_core es super admin de todo el sistema, asi que la fila se crea a
-- mano y nunca por un alta automatica. Va sin auth_user_id: la persona reclama
-- este perfil al entrar por primera vez con ese correo (ensure_profile), igual
-- que cualquier invitacion.
--
-- Cambia el correo por uno real del equipo antes de desplegar. Si se deja el
-- de ejemplo, nadie puede reclamarlo — que es el fallo seguro correcto.

insert into public.profiles (full_name, email, platform_role)
values ('MORPHOS Core', 'core@morphos.example', 'morphos_core')
on conflict do nothing;
