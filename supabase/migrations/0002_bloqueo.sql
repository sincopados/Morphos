-- Bloqueo automático por vencimiento de membresía (ADR-0001).
--
-- Prepago mensual: si al llegar `vence_el` no hay pago del ciclo, la empresa
-- pasa a `bloqueada`. No hay mora ni período de gracia. Al registrar el pago
-- vuelve a `activa` de inmediato y sin pérdida de datos.

create or replace function aplicar_vencimientos()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  afectadas integer;
begin
  update empresas e
  set estado = 'bloqueada'
  from membresias m
  where m.empresa_id = e.id
    and e.estado = 'activa'
    and m.vence_el < current_date;

  get diagnostics afectadas = row_count;
  return afectadas;
end;
$$;

-- Registrar un pago extiende el ciclo y desbloquea en el mismo paso.
create or replace function registrar_pago_membresia(
  p_empresa uuid,
  p_importe numeric,
  p_metodo text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  m membresias;
begin
  if not es_morphos_core() then
    raise exception 'solo morphos_core puede registrar pagos de membresía';
  end if;

  select * into m from membresias where empresa_id = p_empresa for update;
  if not found then
    raise exception 'la empresa no tiene membresía';
  end if;

  insert into pagos_membresia (membresia_id, importe, ciclo, metodo, registrado_por)
  values (
    m.id,
    p_importe,
    date_trunc('month', greatest(m.vence_el, current_date))::date,
    p_metodo,
    auth.uid()
  );

  update membresias
  set vence_el = greatest(vence_el, current_date) + interval '1 month'
  where id = m.id;

  -- Solo se reactiva lo bloqueado; una empresa dada de baja no vuelve por un pago.
  update empresas
  set estado = 'activa'
  where id = p_empresa and estado = 'bloqueada';
end;
$$;

-- Empresas que entran en la ventana de aviso de 7 días naturales.
create or replace function membresias_proximas_a_vencer()
returns table (
  empresa_id uuid,
  nombre text,
  vence_el date,
  dias integer,
  importe numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    e.id,
    e.nombre,
    m.vence_el,
    (m.vence_el - current_date)::integer,
    m.importe
  from membresias m
  join empresas e on e.id = m.empresa_id
  where e.estado = 'activa'
    and m.vence_el between current_date and current_date + 7
  order by m.vence_el;
$$;
