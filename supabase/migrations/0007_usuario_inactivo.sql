-- Un usuario inactivo deja de tener acceso al sistema.
--
-- Hasta ahora `usuarios.activo` era una etiqueta: se pintaba en gris en el
-- Dashboard Global, pero ninguna política lo miraba. Una cuenta desactivada
-- seguía leyendo y escribiendo con normalidad.
--
-- El bloqueo se pone aquí y no solo en el cliente: desactivar a alguien debe
-- surtir efecto aunque llame directamente a /rest/v1.

create or replace function usuario_activo()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from usuarios u
    where u.id = auth.uid() and u.activo
  );
$$;

revoke execute on function usuario_activo() from public;
grant execute on function usuario_activo() to authenticated;

-- ---------------------------------------------------------------------------
-- Roles por empresa
-- ---------------------------------------------------------------------------
-- `rol_en` alimenta casi todas las políticas: si devuelve NULL para un usuario
-- inactivo, se le cae el acceso por la vía principal de golpe.

create or replace function rol_en(p_empresa uuid)
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select p.rol from pertenencias p
  join usuarios u on u.id = p.usuario_id
  where p.usuario_id = auth.uid()
    and p.empresa_id = p_empresa
    and p.activa
    and u.activo;
$$;

-- ---------------------------------------------------------------------------
-- Políticas con subconsulta directa a `pertenencias`
-- ---------------------------------------------------------------------------
-- Estas no pasan por `rol_en`, así que hay que cerrarlas una a una o quedaría
-- un hueco por el que un inactivo seguiría leyendo.

drop policy if exists usuarios_select on usuarios;
create policy usuarios_select on usuarios for select using (
  id = auth.uid()
  or es_morphos_core()
  or (
    usuario_activo() and exists (
      select 1 from pertenencias mi, pertenencias suya
      where mi.usuario_id = auth.uid()
        and mi.rol in ('owner', 'administrador')
        and suya.usuario_id = usuarios.id
        and suya.empresa_id = mi.empresa_id
    )
  )
);

drop policy if exists empresas_select on empresas;
create policy empresas_select on empresas for select using (
  es_morphos_core() or (
    usuario_activo() and exists (
      select 1 from pertenencias p
      where p.empresa_id = empresas.id and p.usuario_id = auth.uid() and p.activa
    )
  )
);

drop policy if exists pertenencias_select on pertenencias;
create policy pertenencias_select on pertenencias for select using (
  es_morphos_core()
  or (usuario_activo() and usuario_id = auth.uid())
  or gestiona_empresa(empresa_id)
);

drop policy if exists obras_select on obras;
create policy obras_select on obras for select using (
  gestiona_empresa(empresa_id) or (
    usuario_activo() and exists (
      select 1 from pertenencias p
      where p.empresa_id = obras.empresa_id and p.usuario_id = auth.uid() and p.activa
    )
  )
);

-- El saldo del trabajador sobrevive al bloqueo de la empresa, pero no a la
-- desactivación de su propia cuenta.
drop policy if exists bloques_select on bloques;
create policy bloques_select on bloques for select using (
  (
    usuario_activo() and exists (
      select 1 from pertenencias p
      where p.id = bloques.pertenencia_id and p.usuario_id = auth.uid()
    )
  )
  or exists (
    select 1 from obras o where o.id = bloques.obra_id and gestiona_empresa(o.empresa_id)
  )
);

drop policy if exists incidencias_select on incidencias;
create policy incidencias_select on incidencias for select using (
  es_morphos_core() or (
    usuario_activo() and exists (
      select 1 from pertenencias p
      where p.empresa_id = incidencias.empresa_id and p.usuario_id = auth.uid()
    )
  )
);

drop policy if exists incidencias_insert on incidencias;
create policy incidencias_insert on incidencias for insert with check (
  abierta_por = auth.uid() and usuario_activo() and exists (
    select 1 from pertenencias p
    where p.empresa_id = incidencias.empresa_id and p.usuario_id = auth.uid()
  )
);

drop policy if exists mensajes_select on incidencia_mensajes;
create policy mensajes_select on incidencia_mensajes for select using (
  es_morphos_core() or (
    usuario_activo() and exists (
      select 1 from incidencias i join pertenencias p on p.empresa_id = i.empresa_id
      where i.id = incidencia_mensajes.incidencia_id and p.usuario_id = auth.uid()
    )
  )
);

drop policy if exists mensajes_insert on incidencia_mensajes;
create policy mensajes_insert on incidencia_mensajes for insert with check (
  autor_id = auth.uid() and usuario_activo()
);

drop policy if exists tareas_select on obra_tareas;
create policy tareas_select on obra_tareas for select using (
  (usuario_activo() and asignado_a = auth.uid())
  or exists (
    select 1 from obras o where o.id = obra_tareas.obra_id and gestiona_empresa(o.empresa_id)
  )
);

drop policy if exists modreq_select on modification_requests;
create policy modreq_select on modification_requests for select using (
  (usuario_activo() and (usuario_afectado = auth.uid() or solicitado_por = auth.uid()))
  or gestiona_empresa(empresa_id)
);

-- `usuarios_update_self` se deja intacta a propósito: un inactivo conserva la
-- lectura de su propia fila (la necesita el cliente para decirle por qué no
-- entra) y el trigger de 0006 ya le impide reactivarse solo.
