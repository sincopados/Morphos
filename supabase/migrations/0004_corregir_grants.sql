-- Corrige 0003.
--
-- Dos cosas salieron mal allí:
--
--   1. `revoke ... from anon` no quita nada cuando el permiso viene del rol
--      PUBLIC, que es el que Postgres concede por defecto en toda función. Para
--      excluir a `anon` hay que revocar de PUBLIC y volver a conceder a los
--      roles que sí lo necesitan.
--
--   2. Al revocar `registrar_pago_membresia` de PUBLIC se dejó también sin
--      permiso a `authenticated`, que es quien la llama desde la ficha de
--      empresa. El botón "Registrar pago" quedaba roto.

-- ---------------------------------------------------------------------------
-- API de la app: solo usuarios con sesión
-- ---------------------------------------------------------------------------

revoke execute on function registrar_pago_membresia(uuid, numeric, text) from public;
grant  execute on function registrar_pago_membresia(uuid, numeric, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Helpers de RLS: `authenticated` los necesita, `anon` no
-- ---------------------------------------------------------------------------
-- Se evalúan dentro de las políticas con el rol de quien consulta, así que sin
-- EXECUTE toda consulta fallaría con "permission denied" en vez de devolver
-- cero filas. Solo informan sobre el propio solicitante (`auth.uid()`).

revoke execute on function es_morphos_core() from public;
revoke execute on function rol_en(uuid) from public;
revoke execute on function gestiona_empresa(uuid) from public;
revoke execute on function empresa_escribible(uuid) from public;

grant execute on function es_morphos_core() to authenticated;
grant execute on function rol_en(uuid) to authenticated;
grant execute on function gestiona_empresa(uuid) to authenticated;
grant execute on function empresa_escribible(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Funciones de trigger: nadie las invoca directamente
-- ---------------------------------------------------------------------------
-- El disparo de un trigger no comprueba el permiso EXECUTE del usuario, así que
-- revocarlas por completo no afecta a los invariantes de ADR-0002.

revoke execute on function assert_morphos_core_excluyente() from public, anon, authenticated;
revoke execute on function assert_raiz_intocable() from public, anon, authenticated;
