-- Cierra una escalada de privilegios en `usuarios`.
--
-- La política `usuarios_update_self` deja a cada uno actualizar su propia fila,
-- pero RLS filtra FILAS, no COLUMNAS: nada impedía que un usuario se pusiera a
-- sí mismo `rol_global = 'morphos_core'` y obtuviera acceso total al sistema.
--
-- Verificado antes del arreglo: una cuenta recién registrada, sin ninguna
-- pertenencia, pasaba de no ver nada a leer todas las empresas y los egresos de
-- MORPHOS con un solo PATCH sobre /rest/v1/usuarios.
--
-- El trigger de ADR-0002 no lo cubría: solo rechaza `morphos_core` cuando el
-- usuario TIENE pertenencias activas, y una cuenta nueva no tiene ninguna.

create or replace function assert_campos_protegidos()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Sin JWT no hay usuario final: es `service_role`, `postgres` o una
  -- migración. Esas rutas ya tienen acceso total por otras vías.
  if auth.uid() is null then
    return new;
  end if;

  if es_morphos_core() then
    return new;
  end if;

  if new.id is distinct from old.id
    or new.email is distinct from old.email
    or new.rol_global is distinct from old.rol_global
    or new.es_raiz is distinct from old.es_raiz
    or new.activo is distinct from old.activo
    or new.eliminado_en is distinct from old.eliminado_en
  then
    raise exception
      'solo morphos_core puede cambiar id, email, rol_global, es_raiz, activo o eliminado_en';
  end if;

  return new;
end;
$$;

-- Sobre la propia fila un usuario solo puede tocar `nombre` y `avatar_url`.
create trigger usuarios_campos_protegidos
  before update on usuarios
  for each row execute function assert_campos_protegidos();

revoke execute on function assert_campos_protegidos() from public, anon, authenticated;
