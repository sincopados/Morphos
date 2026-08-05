-- Cierra una fuga de datos entre empresas en `bloques_calculados`.
--
-- Por defecto una vista se ejecuta con los permisos de quien la creó
-- (`postgres`), no de quien consulta, así que NO aplica el RLS del solicitante:
-- la vista devolvía los bloques de TODAS las empresas.
--
-- Verificado antes del arreglo, con una trabajadora que pertenece a una sola
-- empresa y 11 bloques en el sistema:
--
--   select sobre `bloques`             → 10 filas   (RLS correcto)
--   select sobre `bloques_calculados`  → 11 filas   ← incluía la otra empresa,
--                                                     con su tarifa por hora
--
-- `security_invoker` hace que la vista se evalúe con el rol de quien consulta,
-- de modo que hereda las políticas de la tabla base.

alter view bloques_calculados set (security_invoker = on);
