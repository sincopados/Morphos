-- Permisos de tabla para `authenticated`.
--
-- RLS y GRANT son dos capas distintas y hacen falta las dos: RLS decide QUÉ
-- FILAS ve un usuario, pero sin GRANT ni siquiera puede tocar la tabla y
-- PostgREST responde 42501 "permission denied" antes de evaluar ninguna
-- política.
--
-- `anon` queda deliberadamente fuera de todo: en MORPHOS no hay ni una sola
-- pantalla pública con datos.

grant usage on schema public to authenticated;

grant select, insert, update, delete on all tables in schema public to authenticated;

-- Las vistas derivadas son de solo lectura.
revoke insert, update, delete on bloques_calculados from authenticated;

-- Que las tablas futuras hereden el mismo criterio.
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
