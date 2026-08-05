-- Permisos de tabla para `service_role`.
--
-- Corrige un hueco de 0005, que solo concedió a `authenticated`.
--
-- `service_role` salta RLS, pero eso NO le da permisos de tabla: son dos capas
-- distintas. Sin GRANT, cualquier consulta suya falla con 42501 antes siquiera
-- de llegar a las políticas.
--
-- El síntoma fue silencioso: la ruta de alta de equipo buscaba si el correo ya
-- existía, la consulta fallaba con "permission denied", y al ignorar el error
-- el código concluía que la persona era nueva y pedía una contraseña que no
-- hacía falta. Nunca llegaba a reutilizar una cuenta existente.
--
-- Este rol solo se usa desde server/api/**, nunca desde el navegador.

grant usage on schema public to service_role;

grant select, insert, update, delete on all tables in schema public to service_role;

revoke insert, update, delete on bloques_calculados from service_role;

alter default privileges in schema public
  grant select, insert, update, delete on tables to service_role;
