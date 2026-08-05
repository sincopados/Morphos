-- Datos de ejemplo para desarrollo.
--
-- Pégalo tal cual en el SQL Editor de Supabase. Crea también las cuentas de
-- `auth.users`, así que no hay nada previo que preparar ni UUID que sustituir.
--
-- REINSTALABLE: se puede ejecutar tantas veces como haga falta. Empieza
-- borrando los datos de ejemplo que crea, así que no acumula duplicados ni
-- falla por el `slug` único de las empresas.
--
-- Cuentas que deja creadas, todas con contraseña `MorphosDemo2026!`:
--
--   morphossystem@gmail.com  morphos_core y cuenta raíz
--   duena@morphos.demo       dueña de las dos empresas de ejemplo
--   curra@morphos.demo       trabajadora con check-in en Constructora Sur
--
-- AVISO: esa contraseña está en el repositorio. La cuenta raíz manda sobre todo
-- el sistema: entra en /perfil y cámbiala antes de nada.

-- ---------------------------------------------------------------------------
-- 0. Limpieza — lo que hace reinstalable al seed
-- ---------------------------------------------------------------------------

do $$
begin
  -- La cuenta raíz es intocable por diseño (ADR-0002). Desactivar el trigger es
  -- la vía de administración prevista para casos como este.
  alter table usuarios disable trigger usuarios_raiz_intocable;

  -- Borra en cascada pertenencias, obras, bloques, cobros e incidencias.
  delete from empresas where slug in ('constructora-sur', 'nova-reformas');

  -- Los egresos no cuelgan de ninguna empresa: se borran por concepto para no
  -- tocar los que hayas dado de alta tú. La comparación ignora tildes y
  -- mayúsculas: si no, un "Nomina" sin tilde sobrevive y luego impide borrar
  -- la cuenta que lo registró, por la clave foránea.
  delete from egresos_morphos
  where translate(lower(concepto), 'áéíóúü', 'aeiouu')
    in ('supabase pro', 'dominio y correo', 'nomina interna');

  -- Cuenta de demostración retirada: su contraseña es pública y era raíz.
  delete from auth.users where email = 'core@morphos.demo';

  alter table usuarios enable trigger usuarios_raiz_intocable;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Cuentas de autenticación
-- ---------------------------------------------------------------------------

do $$
declare
  pw      text   := 'MorphosDemo2026!';
  cuentas text[] := array['morphossystem@gmail.com', 'duena@morphos.demo', 'curra@morphos.demo'];
  nombres text[] := array['MORPHOS Core', 'Marta Ruiz', 'Eva Bergara'];
  uid uuid;
  i   int;
begin
  for i in 1..array_length(cuentas, 1) loop
    continue when exists (select 1 from auth.users where email = cuentas[i]);

    uid := gen_random_uuid();

    -- Las columnas de token van a cadena vacía, no a NULL: GoTrue las lee en
    -- structs de Go no anulables y un NULL rompe el login con
    -- "Database error querying schema".
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change,
      email_change_token_new, email_change_token_current,
      phone_change, phone_change_token, reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      uid, 'authenticated', 'authenticated', cuentas[i],
      extensions.crypt(pw, extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', nombres[i]),
      '', '', '', '', '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), uid, uid::text,
      jsonb_build_object('sub', uid::text, 'email', cuentas[i], 'email_verified', true),
      'email', now(), now(), now()
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Datos de negocio
-- ---------------------------------------------------------------------------

do $$
declare
  id_raiz uuid; id_duena uuid; id_curra uuid;
  id_sur uuid; id_nova uuid; id_pert uuid; id_obra uuid; id_cli uuid;
begin
  select id into id_raiz  from auth.users where email = 'morphossystem@gmail.com';
  select id into id_duena from auth.users where email = 'duena@morphos.demo';
  select id into id_curra from auth.users where email = 'curra@morphos.demo';

  if id_raiz is null or id_duena is null or id_curra is null then
    raise exception 'Falta alguna de las cuentas: revisa la sección 1';
  end if;

  -- El trigger on_auth_user_created ya creó las filas en `usuarios`; esto es
  -- solo por si las cuentas son anteriores a la migración.
  insert into usuarios (id, email, nombre)
  values (id_raiz,  'morphossystem@gmail.com', 'MORPHOS Core'),
         (id_duena, 'duena@morphos.demo',      'Marta Ruiz'),
         (id_curra, 'curra@morphos.demo',      'Eva Bergara')
  on conflict (id) do nothing;

  -- Rol global, excluyente y sin pertenencias (ADR-0002).
  update usuarios set rol_global = 'morphos_core', es_raiz = true where id = id_raiz;

  -- Dos empresas de la misma dueña: Sur al día, Nova vencida, para ver las dos
  -- ramas del bloqueo.
  insert into empresas (nombre, slug, jurisdiccion, estado, compliance_cargado)
  values ('Constructora Sur', 'constructora-sur', 'ES', 'activa', true)
  returning id into id_sur;

  insert into empresas (nombre, slug, jurisdiccion, estado, compliance_cargado)
  values ('Nova Reformas', 'nova-reformas', 'ES', 'bloqueada', false)
  returning id into id_nova;

  insert into pertenencias (usuario_id, empresa_id, rol, perfil, tarifa_hora)
  values (id_duena, id_sur,  'owner', 'sin_horario', 0),
         (id_duena, id_nova, 'owner', 'sin_horario', 0);

  -- Rol, tarifa y saldo son de la pertenencia, no del usuario.
  insert into pertenencias (usuario_id, empresa_id, rol, perfil, tarifa_hora)
  values (id_curra, id_sur, 'trabajador', 'con_horario', 29.03)
  returning id into id_pert;

  -- Una membresía por empresa, prepago mensual (ADR-0001).
  insert into membresias (empresa_id, titular_id, importe, vence_el)
  values (id_sur,  id_duena, 149.00, current_date + 5),   -- "próxima a vencer"
         (id_nova, id_duena, 149.00, current_date - 3);   -- venció → bloqueada

  insert into pagos_membresia (membresia_id, importe, ciclo)
  select id, importe, date_trunc('month', current_date)::date
  from membresias where empresa_id = id_sur;

  insert into egresos_morphos (concepto, categoria, importe, registrado_por)
  values ('Supabase Pro',     'infraestructura',   25.00, id_raiz),
         ('Dominio y correo', 'proveedores',       12.50, id_raiz),
         ('Nómina interna',   'nomina',          1800.00, id_raiz);

  insert into clientes (empresa_id, nombre, email)
  values (id_sur, 'Karen Ruiz', 'karen@example.com')
  returning id into id_cli;

  -- Obra virtual: recoge lo que no pertenece a ninguna obra concreta.
  insert into obras (empresa_id, numero, titulo, estado, fecha_inicio)
  values (id_sur, 0, 'General / Empresa', 'activa', current_date - 90);

  insert into obras (empresa_id, numero, titulo, cliente_id, estado, fecha_inicio)
  values (id_sur, 82, 'Reforma Karen (planta 1 y sótano)', id_cli, 'activa', current_date - 20)
  returning id into id_obra;

  insert into obra_lineas (obra_id, orden, nombre, cantidad, coste_unitario, precio_unitario)
  values (id_obra, 1, 'Demolición',           1, 800, 1600),
         (id_obra, 2, 'Reparación de parqué', 45,  22,   48);

  insert into obra_gastos (obra_id, concepto, importe, estado)
  values (id_obra, 'Contenedor de escombros', 320.00, 'confirmado'),
         (id_obra, 'Alquiler de martillo',     95.00, 'pendiente');  -- no suma

  -- Mano de obra derivada del check-in, con la tarifa congelada en la fecha del
  -- bloque. Los dos últimos días quedan pendientes de aprobación.
  insert into bloques (pertenencia_id, obra_id, fecha, tipo, tarifa_hora, estado)
  select id_pert, id_obra, current_date - n,
         case when n % 3 = 0 then 'medio_dia'::bloque_tipo
                             else 'dia_completo'::bloque_tipo end,
         29.03,
         case when n < 2 then 'pendiente'::registro_estado
                         else 'confirmado'::registro_estado end
  from generate_series(0, 9) as n;

  insert into obra_tareas (obra_id, titulo, fecha_limite, estado)
  values (id_obra, 'Pedir azulejos',                current_date - 2, 'abierta'),  -- vencida
         (id_obra, 'Revisar instalación eléctrica', current_date + 4, 'abierta');

  -- Cobro ≠ venta: solo el confirmado suma al dashboard.
  insert into cobros (obra_id, fecha, importe, tipo, estado)
  values (id_obra, current_date - 1, 1500.00, 'deposito', 'confirmado'),
         (id_obra, current_date,      900.00, 'pago',     'pendiente');

  -- Incidencia abierta desde la pantalla de bloqueo de la empresa vencida.
  insert into incidencias (empresa_id, abierta_por, asunto, tipo, prioridad)
  values (id_nova, id_duena, 'Tengo un problema con el pago', 'pago', 'alta');
end $$;
