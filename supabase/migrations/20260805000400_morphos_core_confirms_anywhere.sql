-- morphos_core puede confirmar en cualquier empresa
--
-- Decision del dueno del producto: se deja de aplicar la puerta que exigia
-- `companies.supervision_contracted` para que morphos_core confirmara o
-- rechazara movimientos (la "regla no-negociable #2" de CONTEXT.md). A partir
-- de aqui morphos_core es super admin sin excepciones: confirma en cualquier
-- empresa, contratada o no.
--
-- Lo que se pierde con esto, para que quede escrito: `confirmed_by` sigue
-- diciendo *quien* confirmo, pero ya no se puede deducir del estado de la
-- empresa si esa confirmacion fue un servicio contratado o una intervencion de
-- soporte. Si mas adelante hace falta esa distincion, la via es marcarla en el
-- propio registro (p. ej. en `ledger_entries.metadata`) y no volver a atarla a
-- un flag de la empresa.
--
-- `supervision_contracted` NO se elimina: sigue siendo el estado comercial de
-- la empresa (contratada o no, y desde cuando) y el panel de sistema lo sigue
-- gestionando. Simplemente deja de conceder o negar permisos.

create or replace function private.can_confirm_for(target_company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_company_owner(target_company))
    or (select private.is_morphos_core());
$$;
