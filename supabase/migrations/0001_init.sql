-- MORPHOS — esquema inicial
-- Modelo documentado en CONTEXT-MAP.md y docs/spec/.
--
-- Dos contextos (ADR-0003):
--   Operación  — empresas, obras, gente y dinero con clientes finales.
--   Comercial  — membresías, bloqueo, soporte y dinero de MORPHOS.

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------

create type user_role as enum (
  'owner', 'administrador', 'trabajador', 'vendedor', 'afiliado'
);

-- morphos_core es global y excluyente (ADR-0002): no vive en `pertenencias`.
create type global_role as enum ('morphos_core');

create type profile_type as enum ('con_horario', 'sin_horario');

create type empresa_estado as enum ('activa', 'bloqueada', 'dada_de_baja');

create type obra_estado as enum (
  'borrador', 'activa', 'atrasada', 'completada', 'cerrada', 'archivada'
);

create type obra_tipo as enum ('puntual', 'recurrente');

create type registro_estado as enum ('pendiente', 'confirmado');

create type cobro_tipo as enum ('deposito', 'pago', 'pago_final');

create type factura_estado as enum ('proxima', 'enviada', 'vencida', 'pagada');

create type tarea_estado as enum ('abierta', 'en_curso', 'completada');

create type visita_estado as enum (
  'programada', 'en_curso', 'completada', 'vencida'
);

create type bloque_tipo as enum ('dia_completo', 'medio_dia');

create type egreso_categoria as enum (
  'infraestructura', 'nomina', 'proveedores', 'comisiones', 'otros'
);

create type incidencia_estado as enum ('abierta', 'en_curso', 'cerrada');

create type incidencia_prioridad as enum ('baja', 'media', 'alta');

create type incidencia_tipo as enum (
  'pago', 'saldo', 'datos', 'tecnico', 'otro'
);

-- ---------------------------------------------------------------------------
-- Usuarios
-- ---------------------------------------------------------------------------

create table usuarios (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text        not null unique,
  nombre       text        not null,
  avatar_url   text,
  -- Rol global. Hoy solo 'morphos_core'.
  rol_global   global_role,
  -- Cuenta raíz: ningún morphos_core puede eliminarla ni degradarla (ADR-0002).
  es_raiz      boolean     not null default false,
  activo       boolean     not null default true,
  eliminado_en timestamptz,
  created_at   timestamptz not null default now(),

  -- Solo un morphos_core puede ser raíz.
  constraint raiz_es_morphos_core
    check (not es_raiz or rol_global = 'morphos_core')
);

create index usuarios_rol_global_idx on usuarios (rol_global);

-- ---------------------------------------------------------------------------
-- Empresas (núcleo compartido entre los dos contextos)
-- ---------------------------------------------------------------------------

create table empresas (
  id                      uuid primary key default gen_random_uuid(),
  nombre                  text           not null,
  slug                    text           not null unique,
  jurisdiccion            text           not null default 'ES',
  zona_horaria            text           not null default 'Europe/Madrid',
  estado                  empresa_estado not null default 'activa',
  supervision_contratada  boolean        not null default false,
  supervision_desde       date,
  compliance_cargado      boolean        not null default false,
  dada_de_baja_en         timestamptz,
  created_at              timestamptz    not null default now()
);

create index empresas_estado_idx on empresas (estado);

-- ---------------------------------------------------------------------------
-- Pertenencias — rol, tarifa y saldo viven aquí, no en el usuario
-- ---------------------------------------------------------------------------

create table pertenencias (
  id           uuid primary key default gen_random_uuid(),
  usuario_id   uuid         not null references usuarios (id) on delete cascade,
  empresa_id   uuid         not null references empresas (id) on delete cascade,
  rol          user_role    not null,
  perfil       profile_type not null,
  tarifa_hora  numeric(12, 2) not null default 0,
  activa       boolean      not null default true,
  created_at   timestamptz  not null default now(),

  unique (usuario_id, empresa_id)
);

create index pertenencias_empresa_idx on pertenencias (empresa_id);
create index pertenencias_usuario_idx on pertenencias (usuario_id);

-- morphos_core es excluyente con cualquier pertenencia (ADR-0002).
create or replace function assert_morphos_core_excluyente()
returns trigger
language plpgsql
as $$
begin
  if tg_table_name = 'pertenencias' then
    if exists (
      select 1 from usuarios u
      where u.id = new.usuario_id and u.rol_global = 'morphos_core'
    ) then
      raise exception
        'morphos_core es excluyente: no puede pertenecer a ninguna empresa';
    end if;
  else
    if new.rol_global = 'morphos_core' and exists (
      select 1 from pertenencias p
      where p.usuario_id = new.id and p.activa
    ) then
      raise exception
        'no se puede asignar morphos_core a un usuario con pertenencias activas';
    end if;
  end if;

  return new;
end;
$$;

create trigger pertenencias_excluyente
  before insert or update on pertenencias
  for each row execute function assert_morphos_core_excluyente();

create trigger usuarios_excluyente
  before insert or update of rol_global on usuarios
  for each row execute function assert_morphos_core_excluyente();

-- La cuenta raíz es intocable, ni siquiera para sí misma (ADR-0002).
create or replace function assert_raiz_intocable()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.es_raiz then
      raise exception 'la cuenta raíz no se puede eliminar';
    end if;
    return old;
  end if;

  if old.es_raiz and (
    new.rol_global is distinct from 'morphos_core'
    or new.es_raiz = false
    or new.activo = false
  ) then
    raise exception 'la cuenta raíz no se puede degradar ni suspender';
  end if;

  return new;
end;
$$;

create trigger usuarios_raiz_intocable
  before update or delete on usuarios
  for each row execute function assert_raiz_intocable();

-- ---------------------------------------------------------------------------
-- Comercial — membresías (una por empresa, prepago mensual, ADR-0001)
-- ---------------------------------------------------------------------------

create table membresias (
  id          uuid primary key default gen_random_uuid(),
  empresa_id  uuid           not null unique references empresas (id) on delete cascade,
  titular_id  uuid           not null references usuarios (id),
  importe     numeric(12, 2) not null,
  moneda      text           not null default 'EUR',
  -- Fin del ciclo pagado. Sin pago ese día, la empresa se bloquea.
  vence_el    date           not null,
  created_at  timestamptz    not null default now()
);

create index membresias_vence_idx on membresias (vence_el);

create table pagos_membresia (
  id            uuid primary key default gen_random_uuid(),
  membresia_id  uuid           not null references membresias (id) on delete cascade,
  fecha         date           not null default current_date,
  importe       numeric(12, 2) not null,
  -- Ciclo que cubre este pago: el recaudo se devenga aquí.
  ciclo         date           not null,
  metodo        text,
  fallido       boolean        not null default false,
  registrado_por uuid          references usuarios (id),
  created_at    timestamptz    not null default now()
);

create index pagos_membresia_ciclo_idx on pagos_membresia (ciclo);

create table egresos_morphos (
  id             uuid primary key default gen_random_uuid(),
  fecha          date             not null default current_date,
  concepto       text             not null,
  categoria      egreso_categoria not null,
  importe        numeric(12, 2)   not null,
  comprobante_url text,
  registrado_por uuid             not null references usuarios (id),
  created_at     timestamptz      not null default now()
);

create index egresos_fecha_idx on egresos_morphos (fecha);

-- ---------------------------------------------------------------------------
-- Comercial — soporte
-- ---------------------------------------------------------------------------

create table incidencias (
  id           uuid primary key default gen_random_uuid(),
  empresa_id   uuid                 not null references empresas (id) on delete cascade,
  abierta_por  uuid                 not null references usuarios (id),
  asunto       text                 not null,
  tipo         incidencia_tipo      not null default 'otro',
  prioridad    incidencia_prioridad not null default 'media',
  estado       incidencia_estado    not null default 'abierta',
  responsable  uuid                 references usuarios (id),
  created_at   timestamptz          not null default now(),
  cerrada_en   timestamptz
);

create index incidencias_estado_idx on incidencias (estado);

create table incidencia_mensajes (
  id             uuid primary key default gen_random_uuid(),
  incidencia_id  uuid        not null references incidencias (id) on delete cascade,
  autor_id       uuid        not null references usuarios (id),
  cuerpo         text        not null,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Operación — clientes finales y obras
-- ---------------------------------------------------------------------------

create table clientes (
  id          uuid primary key default gen_random_uuid(),
  empresa_id  uuid        not null references empresas (id) on delete cascade,
  nombre      text        not null,
  email       text,
  telefono    text,
  direccion   text,
  created_at  timestamptz not null default now()
);

create index clientes_empresa_idx on clientes (empresa_id);

create table obras (
  id                 uuid primary key default gen_random_uuid(),
  empresa_id         uuid           not null references empresas (id) on delete cascade,
  numero             integer        not null,
  titulo             text           not null,
  cliente_id         uuid           references clientes (id),
  direccion_obra     text,
  tipo               obra_tipo      not null default 'puntual',
  estado             obra_estado    not null default 'borrador',
  fecha_inicio       date,
  fecha_fin          date,
  vendedor_id        uuid           references usuarios (id),
  deposito_requerido numeric(12, 2) not null default 0,
  notas_internas     text,
  creado_por         uuid           references usuarios (id),
  created_at         timestamptz    not null default now(),
  updated_at         timestamptz    not null default now(),

  -- Correlativo por empresa, nunca reutilizado.
  unique (empresa_id, numero)
);

create index obras_empresa_estado_idx on obras (empresa_id, estado);

-- La obra virtual "General / Empresa" existe siempre y no se puede borrar.
create table obra_lineas (
  id              uuid primary key default gen_random_uuid(),
  obra_id         uuid           not null references obras (id) on delete cascade,
  orden           integer        not null default 0,
  nombre          text           not null,
  descripcion     text,
  cantidad        numeric(12, 2) not null default 1,
  coste_unitario  numeric(12, 2) not null default 0,
  precio_unitario numeric(12, 2) not null default 0,
  es_incluido     boolean        not null default false
);

create index obra_lineas_obra_idx on obra_lineas (obra_id);

create table obra_gastos (
  id             uuid primary key default gen_random_uuid(),
  obra_id        uuid            not null references obras (id) on delete cascade,
  fecha          date            not null default current_date,
  concepto       text            not null,
  categoria      text,
  importe        numeric(12, 2)  not null,
  proveedor      text,
  comprobante_url text,
  registrado_por uuid            references usuarios (id),
  estado         registro_estado not null default 'pendiente',
  created_at     timestamptz     not null default now()
);

create index obra_gastos_obra_idx on obra_gastos (obra_id);

-- Mano de obra: derivada del check-in, nunca tecleada.
create table bloques (
  id             uuid primary key default gen_random_uuid(),
  pertenencia_id uuid            not null references pertenencias (id) on delete cascade,
  obra_id        uuid            not null references obras (id) on delete cascade,
  fecha          date            not null default current_date,
  tipo           bloque_tipo     not null,
  entrada_at     timestamptz,
  salida_at      timestamptz,
  ajuste_horas   numeric(6, 2)   not null default 0,
  -- Tarifa congelada en la fecha del bloque: cambiarla hoy no reescribe el pasado.
  tarifa_hora    numeric(12, 2)  not null,
  notas          text,
  estado         registro_estado not null default 'pendiente',
  created_at     timestamptz     not null default now()
);

create index bloques_obra_idx on bloques (obra_id);
create index bloques_pertenencia_idx on bloques (pertenencia_id);

create view bloques_calculados as
select
  b.*,
  (case b.tipo when 'dia_completo' then 8 else 4 end) + b.ajuste_horas as horas,
  ((case b.tipo when 'dia_completo' then 8 else 4 end) + b.ajuste_horas)
    * b.tarifa_hora as coste
from bloques b;

create table obra_tareas (
  id           uuid primary key default gen_random_uuid(),
  obra_id      uuid         not null references obras (id) on delete cascade,
  titulo       text         not null,
  asignado_a   uuid         references usuarios (id),
  fecha_limite date,
  estado       tarea_estado not null default 'abierta',
  prioridad    incidencia_prioridad not null default 'media',
  created_at   timestamptz  not null default now()
);

create index obra_tareas_obra_idx on obra_tareas (obra_id, estado);

create table obra_visitas (
  id                uuid          primary key default gen_random_uuid(),
  obra_id           uuid          not null references obras (id) on delete cascade,
  titulo            text          not null,
  instrucciones     text,
  fecha_hora_inicio timestamptz   not null,
  fecha_hora_fin    timestamptz,
  estado            visita_estado not null default 'programada'
);

create index obra_visitas_obra_idx on obra_visitas (obra_id);

-- ---------------------------------------------------------------------------
-- Operación — facturación y cobros
-- ---------------------------------------------------------------------------

create table facturas (
  id                uuid primary key default gen_random_uuid(),
  empresa_id        uuid            not null references empresas (id) on delete cascade,
  cliente_id        uuid            references clientes (id),
  numero            integer         not null,
  asunto            text,
  fecha_vencimiento date,
  estado            factura_estado  not null default 'proxima',
  total             numeric(12, 2)  not null default 0,
  created_at        timestamptz     not null default now(),

  unique (empresa_id, numero)
);

create table cobros (
  id          uuid primary key default gen_random_uuid(),
  obra_id     uuid            not null references obras (id) on delete cascade,
  factura_id  uuid            references facturas (id),
  fecha       date            not null default current_date,
  importe     numeric(12, 2)  not null,
  metodo      text,
  tipo        cobro_tipo      not null default 'pago',
  -- Cobro ≠ venta: solo los confirmados suman al dashboard.
  estado      registro_estado not null default 'pendiente',
  created_at  timestamptz     not null default now()
);

create index cobros_obra_idx on cobros (obra_id);
create index cobros_fecha_idx on cobros (fecha);

-- ---------------------------------------------------------------------------
-- Auditoría y solicitudes de modificación
-- ---------------------------------------------------------------------------

create table modification_requests (
  id            uuid primary key default gen_random_uuid(),
  empresa_id    uuid        not null references empresas (id) on delete cascade,
  tabla         text        not null,
  registro_id   uuid        not null,
  motivo        text        not null,
  solicitado_por uuid       not null references usuarios (id),
  usuario_afectado uuid     references usuarios (id),
  resuelta      boolean     not null default false,
  created_at    timestamptz not null default now()
);

create table audit_log (
  id            uuid primary key default gen_random_uuid(),
  usuario_id    uuid        references usuarios (id),
  actuando_como text        not null,
  empresa_id    uuid        references empresas (id),
  tabla         text        not null,
  registro_id   uuid,
  accion        text        not null,
  valor_anterior jsonb,
  valor_nuevo   jsonb,
  created_at    timestamptz not null default now()
);

create index audit_log_empresa_idx on audit_log (empresa_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Helpers de autorización
-- ---------------------------------------------------------------------------

create or replace function es_morphos_core()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from usuarios u
    where u.id = auth.uid()
      and u.rol_global = 'morphos_core'
      and u.activo
  );
$$;

create or replace function rol_en(p_empresa uuid)
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select p.rol from pertenencias p
  where p.usuario_id = auth.uid() and p.empresa_id = p_empresa and p.activa;
$$;

create or replace function empresa_escribible(p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  -- Con la empresa bloqueada nadie escribe salvo morphos_core (docs/spec/30 §3).
  select es_morphos_core() or exists (
    select 1 from empresas e
    where e.id = p_empresa and e.estado = 'activa'
  );
$$;

create or replace function gestiona_empresa(p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select es_morphos_core() or rol_en(p_empresa) in ('owner', 'administrador');
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table usuarios              enable row level security;
alter table empresas              enable row level security;
alter table pertenencias          enable row level security;
alter table membresias            enable row level security;
alter table pagos_membresia       enable row level security;
alter table egresos_morphos       enable row level security;
alter table incidencias           enable row level security;
alter table incidencia_mensajes   enable row level security;
alter table clientes              enable row level security;
alter table obras                 enable row level security;
alter table obra_lineas           enable row level security;
alter table obra_gastos           enable row level security;
alter table bloques               enable row level security;
alter table obra_tareas           enable row level security;
alter table obra_visitas          enable row level security;
alter table facturas              enable row level security;
alter table cobros                enable row level security;
alter table modification_requests enable row level security;
alter table audit_log             enable row level security;

-- Usuarios: cada uno se ve a sí mismo; morphos_core ve y gestiona a todos.
create policy usuarios_select on usuarios for select using (
  id = auth.uid()
  or es_morphos_core()
  or exists (
    select 1 from pertenencias mi, pertenencias suya
    where mi.usuario_id = auth.uid()
      and mi.rol in ('owner', 'administrador')
      and suya.usuario_id = usuarios.id
      and suya.empresa_id = mi.empresa_id
  )
);
create policy usuarios_update_self on usuarios for update using (id = auth.uid());
create policy usuarios_all_core on usuarios for all using (es_morphos_core());

-- Empresas: se ven las propias; solo morphos_core crea, edita y da de baja.
create policy empresas_select on empresas for select using (
  es_morphos_core() or exists (
    select 1 from pertenencias p
    where p.empresa_id = empresas.id and p.usuario_id = auth.uid() and p.activa
  )
);
create policy empresas_all_core on empresas for all using (es_morphos_core());

create policy pertenencias_select on pertenencias for select using (
  usuario_id = auth.uid() or es_morphos_core() or gestiona_empresa(empresa_id)
);
create policy pertenencias_write on pertenencias for all using (
  es_morphos_core() or (rol_en(empresa_id) = 'owner' and empresa_escribible(empresa_id))
);

-- Comercial: las empresas leen su propia membresía; el resto es de morphos_core.
create policy membresias_select on membresias for select using (
  es_morphos_core() or rol_en(empresa_id) = 'owner'
);
create policy membresias_all_core on membresias for all using (es_morphos_core());
create policy pagos_all_core on pagos_membresia for all using (es_morphos_core());
create policy egresos_all_core on egresos_morphos for all using (es_morphos_core());

-- Soporte: cualquier rol abre incidencias de su empresa, incluso bloqueada.
create policy incidencias_select on incidencias for select using (
  es_morphos_core() or exists (
    select 1 from pertenencias p
    where p.empresa_id = incidencias.empresa_id and p.usuario_id = auth.uid()
  )
);
create policy incidencias_insert on incidencias for insert with check (
  abierta_por = auth.uid() and exists (
    select 1 from pertenencias p
    where p.empresa_id = incidencias.empresa_id and p.usuario_id = auth.uid()
  )
);
create policy incidencias_update_core on incidencias for update using (es_morphos_core());

create policy mensajes_select on incidencia_mensajes for select using (
  es_morphos_core() or exists (
    select 1 from incidencias i join pertenencias p on p.empresa_id = i.empresa_id
    where i.id = incidencia_mensajes.incidencia_id and p.usuario_id = auth.uid()
  )
);
create policy mensajes_insert on incidencia_mensajes for insert with check (
  autor_id = auth.uid()
);

-- Operación: lectura para quien gestiona la empresa; escritura solo si activa.
create policy clientes_select on clientes for select using (gestiona_empresa(empresa_id));
create policy clientes_write on clientes for all using (
  gestiona_empresa(empresa_id) and empresa_escribible(empresa_id)
);

create policy obras_select on obras for select using (
  gestiona_empresa(empresa_id) or exists (
    select 1 from pertenencias p
    where p.empresa_id = obras.empresa_id and p.usuario_id = auth.uid() and p.activa
  )
);
create policy obras_write on obras for all using (
  gestiona_empresa(empresa_id) and empresa_escribible(empresa_id)
);

create policy lineas_select on obra_lineas for select using (
  exists (select 1 from obras o where o.id = obra_lineas.obra_id and gestiona_empresa(o.empresa_id))
);
create policy lineas_write on obra_lineas for all using (
  exists (
    select 1 from obras o
    where o.id = obra_lineas.obra_id
      and gestiona_empresa(o.empresa_id) and empresa_escribible(o.empresa_id)
  )
);

create policy gastos_select on obra_gastos for select using (
  exists (select 1 from obras o where o.id = obra_gastos.obra_id and gestiona_empresa(o.empresa_id))
);
create policy gastos_write on obra_gastos for all using (
  exists (
    select 1 from obras o
    where o.id = obra_gastos.obra_id
      and gestiona_empresa(o.empresa_id) and empresa_escribible(o.empresa_id)
  )
);

-- Bloques: el trabajador ve y crea los suyos; quien gestiona ve los de la obra.
-- Con la empresa bloqueada el trabajador conserva la lectura de su saldo.
create policy bloques_select on bloques for select using (
  exists (
    select 1 from pertenencias p
    where p.id = bloques.pertenencia_id and p.usuario_id = auth.uid()
  )
  or exists (
    select 1 from obras o where o.id = bloques.obra_id and gestiona_empresa(o.empresa_id)
  )
);
create policy bloques_insert on bloques for insert with check (
  exists (
    select 1 from pertenencias p
    where p.id = bloques.pertenencia_id
      and p.usuario_id = auth.uid()
      and empresa_escribible(p.empresa_id)
  )
);
create policy bloques_update on bloques for update using (
  exists (
    select 1 from obras o
    where o.id = bloques.obra_id
      and gestiona_empresa(o.empresa_id) and empresa_escribible(o.empresa_id)
  )
);

create policy tareas_select on obra_tareas for select using (
  asignado_a = auth.uid() or exists (
    select 1 from obras o where o.id = obra_tareas.obra_id and gestiona_empresa(o.empresa_id)
  )
);
create policy tareas_write on obra_tareas for all using (
  exists (
    select 1 from obras o
    where o.id = obra_tareas.obra_id
      and gestiona_empresa(o.empresa_id) and empresa_escribible(o.empresa_id)
  )
);

create policy visitas_select on obra_visitas for select using (
  exists (select 1 from obras o where o.id = obra_visitas.obra_id and gestiona_empresa(o.empresa_id))
);
create policy visitas_write on obra_visitas for all using (
  exists (
    select 1 from obras o
    where o.id = obra_visitas.obra_id
      and gestiona_empresa(o.empresa_id) and empresa_escribible(o.empresa_id)
  )
);

create policy facturas_select on facturas for select using (gestiona_empresa(empresa_id));
create policy facturas_write on facturas for all using (
  gestiona_empresa(empresa_id) and empresa_escribible(empresa_id)
);

create policy cobros_select on cobros for select using (
  exists (select 1 from obras o where o.id = cobros.obra_id and gestiona_empresa(o.empresa_id))
);
create policy cobros_write on cobros for all using (
  exists (
    select 1 from obras o
    where o.id = cobros.obra_id
      and gestiona_empresa(o.empresa_id) and empresa_escribible(o.empresa_id)
  )
);

create policy modreq_select on modification_requests for select using (
  usuario_afectado = auth.uid()
  or solicitado_por = auth.uid()
  or gestiona_empresa(empresa_id)
);
create policy modreq_insert on modification_requests for insert with check (
  solicitado_por = auth.uid() and gestiona_empresa(empresa_id)
);

create policy audit_select on audit_log for select using (
  es_morphos_core() or (empresa_id is not null and rol_en(empresa_id) = 'owner')
);

-- ---------------------------------------------------------------------------
-- Alta automática de usuario al registrarse
-- ---------------------------------------------------------------------------

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into usuarios (id, email, nombre, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
