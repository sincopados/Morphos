-- Endurecimiento de funciones, a raíz del linter de seguridad de Supabase.
--
-- Toda función en `public` queda expuesta como `/rest/v1/rpc/<nombre>`. Las que
-- no forman parte de la API de la app no deben ser invocables desde el cliente.

-- ---------------------------------------------------------------------------
-- 1. search_path fijo en los triggers que hacen cumplir los invariantes
-- ---------------------------------------------------------------------------
-- Sin search_path fijo, quien pueda crear objetos en un esquema anterior podría
-- suplantar las tablas que consultan y anular las comprobaciones de ADR-0002.

alter function assert_morphos_core_excluyente() set search_path = public;
alter function assert_raiz_intocable() set search_path = public;

-- ---------------------------------------------------------------------------
-- 2. Funciones que nunca debe llamar un cliente
-- ---------------------------------------------------------------------------

-- Tarea de mantenimiento: bloquea empresas en masa. Solo pg_cron / service_role.
revoke execute on function aplicar_vencimientos() from anon, authenticated, public;

-- Función de trigger: no tiene sentido invocarla directamente.
revoke execute on function handle_new_user() from anon, authenticated, public;

-- La app calcula las próximas a vencer en el Dashboard Global; el RPC sobra.
revoke execute on function membresias_proximas_a_vencer() from anon, authenticated, public;

-- ---------------------------------------------------------------------------
-- 3. Funciones de la API de la app
-- ---------------------------------------------------------------------------

-- La llama morphos_core desde la ficha de empresa. Ya comprueba el rol por
-- dentro, pero un anónimo no tiene por qué poder ni intentarlo.
revoke execute on function registrar_pago_membresia(uuid, numeric, text) from anon, public;

-- ---------------------------------------------------------------------------
-- 4. Helpers de RLS — se dejan concedidos a propósito
-- ---------------------------------------------------------------------------
-- `es_morphos_core`, `rol_en`, `gestiona_empresa` y `empresa_escribible` se
-- evalúan dentro de las políticas RLS con el rol de quien consulta, así que
-- `authenticated` NECESITA EXECUTE: revocarlo rompería todas las consultas con
-- "permission denied" en lugar de devolver cero filas.
--
-- Solo informan sobre el propio solicitante (`auth.uid()`), de modo que no
-- filtran datos de terceros. Se revoca únicamente a `anon`, que nunca consulta
-- estas tablas.

revoke execute on function es_morphos_core() from anon;
revoke execute on function rol_en(uuid) from anon;
revoke execute on function gestiona_empresa(uuid) from anon;
revoke execute on function empresa_escribible(uuid) from anon;
