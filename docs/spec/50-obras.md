# Módulo de Obras

Glosario: [Operación](../../contexts/operacion/CONTEXT.md).

Referencia funcional: Jobber (pantalla de *Job*). MORPHOS adapta ese
modelo, con una diferencia estructural: **la mano de obra no se teclea
a mano — se deriva del sistema de check-in de cada trabajador**
(perfil `con_horario`).

## 1. Entidad `obras`

| Campo | Tipo | Origen / notas |
|---|---|---|
| `id` | uuid | |
| `empresa_id` | fk → `empresas` | Una obra pertenece a una sola empresa |
| `numero` | int | Correlativo **por empresa** (Job # 82). Nunca se reutiliza |
| `titulo` | text | "Karen Renovation (1st floor & Basement)" |
| `cliente_id` | fk → `clientes` | Nombre, dirección de la propiedad, teléfono, email |
| `direccion_obra` | text | Puede diferir de la dirección fiscal del cliente |
| `tipo` | enum | `puntual` (one-off) \| `recurrente` |
| `estado` | enum | `borrador`, `activa`, `atrasada`, `completada`, `cerrada`, `archivada` |
| `fecha_inicio` / `fecha_fin` | date | "Started on" / "Ends on" |
| `frecuencia_facturacion` | enum | `al_completar`, `mensual`, `por_visita`, `hitos` |
| `pagos_automaticos` | bool | |
| `vendedor_id` | fk → `usuarios` (rol `vendedor`) | "Salesperson". Base de la comisión |
| `cotizacion_id` | fk → `cotizaciones` | "From Quote #5". Al aceptar la cotización se crea la obra copiando sus líneas |
| `deposito_requerido` | money | |
| `creado_por`, `created_at`, `updated_at` | | Auditoría |

**Estado `atrasada`**: se calcula, no se teclea — una obra está
atrasada cuando tiene visitas o tareas vencidas sin completar, o pasó
`fecha_fin` sin estar completada.

## 2. `obra_lineas` — Producto / Servicio

Es el precio pactado con el cliente, no el coste real.

| Campo | Notas |
|---|---|
| `obra_id` | fk |
| `orden` | posición en la lista |
| `nombre` | "Demolición", "Hardwood floor Repair"… |
| `descripcion` | texto multilínea con el detalle del alcance |
| `imagen_id` | fk → `archivos` (miniatura de referencia) |
| `cantidad` | decimal |
| `coste_unitario` | money — coste estimado, puede ser 0 |
| `precio_unitario` | money — lo que paga el cliente |
| `total` | derivado = `cantidad × precio_unitario` |
| `es_incluido` | bool — líneas informativas a $0 ("Materials and equipment") |

Totales del bloque (todos derivados, nunca almacenados):
`coste_total`, `precio_total`, `deposito_requerido`,
`deposito_cobrado` (suma de cobros de tipo depósito, con su fecha),
`deposito_pendiente`.

## 3. Mano de obra — derivada del check-in

En Jobber la tabla *Labor* se llena a mano. En MORPHOS **no existe alta
manual de horas**: cada fila es la proyección de un registro de
check-in del trabajador.

- Fuente: los bloques (día completo = 8 h, medio día = 4 h, más
  extra/deducción opcional) del perfil `con_horario`.
- El trabajador, al hacer check-in, selecciona **a qué obra** imputa el
  bloque. Sin obra, cae en "General / Empresa".
- Vista por fila: trabajador, notas, fecha, hora de entrada y salida,
  duración, coste. Totales al pie (p. ej. 120 h → $3.483,04) y
  paginación.
- `coste_mano_obra = horas × tarifa_hora` vigente en la fecha del
  bloque. La tarifa se versiona: cambiarla hoy no reescribe el coste de
  obras pasadas.
- Solo suman los bloques **confirmados**. Un bloque pendiente de
  aprobación aparece marcado y no entra en el coste.
- Correcciones: se ajusta el registro de check-in origen, bajo la
  ventana de 72 h. La obra se recalcula sola.

## 4. `obra_gastos` — Expenses

Gastos directos imputados a la obra: materiales, alquiler de equipo,
vertedero, subcontratas.

| Campo | Notas |
|---|---|
| `obra_id`, `fecha`, `concepto`, `categoria` | |
| `importe`, `proveedor` | |
| `comprobante_id` | fk → `archivos` (foto/PDF del ticket) |
| `registrado_por` | usuario que lo dio de alta |
| `estado` | `pendiente` \| `confirmado` — solo los confirmados suman |

## 5. `obra_visitas` — Scheduled visits

| Campo | Notas |
|---|---|
| `obra_id`, `fecha_hora_inicio`, `fecha_hora_fin` | |
| `titulo`, `instrucciones` | |
| `estado` | `programada`, `en_curso`, `completada`, `vencida` (*Overdue*) |
| `asignados[]` | fk → `usuarios` (uno o varios) |
| `checklist_id` | fk → `checklists` |
| `ventana_llegada` | "Arrive at start time" o rango horario |

La **primera visita** ("First visit") es un derivado: la visita de
menor fecha.

## 6. Tareas

`obra_tareas` con `obra_id`, `titulo`, `asignado_a`, `fecha_limite`,
`estado` (`abierta`, `en_curso`, `completada`) y `prioridad`. Una
visita vencida cuenta como tarea vencida de esa obra.

## 7. Facturación y cobros

- `recordatorios` — configuración de cuándo avisar (p. ej. "cuando la
  obra se marque como cerrada").
- `facturas` (fk `obra_id`, `cliente_id`): número, fecha de
  vencimiento, estado (`proxima`, `enviada`, `vencida`, `pagada`),
  asunto, total, saldo.
- Una factura puede agrupar **varias obras del mismo cliente**: al
  facturar se listan las obras con importe *no facturado* y subtotal, y
  el usuario elige cuáles incluir. Depósitos y descuentos ya cobrados
  se restan automáticamente.
- `cobros` (fk `factura_id` u `obra_id`): fecha, importe, método, tipo
  (`deposito` \| `pago` \| `pago_final`). **Solo los cobros confirmados
  suman al dashboard.**

## 8. Panel económico de la obra

Réplica del panel lateral "Total cost to date", calculado siempre en
vivo:

- **Ingresos** = suma de `obra_lineas.total` (precio pactado).
- **Coste** = mano de obra derivada del check-in (§3) + gastos
  confirmados (§4).
- **Beneficio** = ingresos − coste, con su porcentaje.
- **Actividad reciente** — últimos eventos de la obra ("eberg registró
  8 h de trabajo, hace 3 h").
- **Notas internas** — visibles para `owner` y `administrador`
  asignado; nunca para el cliente.

## 9. Enlace con el dashboard de empresa

- *Cobros por obra* = suma de `cobros` confirmados de la obra.
- *Gastos por obra* = mano de obra (§3) + `obra_gastos` confirmados.
- *Generado en la semana* = cobros confirmados de todas las obras en la
  semana en curso.
- *Tareas pendientes por obra* = `obra_tareas` abiertas + visitas
  vencidas.

## 10. Permisos

| Acción | `owner` | `administrador` | `trabajador` | `vendedor` |
|---|---|---|---|---|
| Crear / editar obra | Sí | Solo sus obras asignadas | No | No |
| Ver panel económico | Sí | Solo sus obras | No | No |
| Registrar horas | — | — | Vía check-in propio | — |
| Alta de gastos | Sí | Sí, en sus obras | No | No |
| Facturar y cobrar | Sí | Según permiso del `owner` | No | No |
| Ver sus visitas/tareas | Sí | Sí | Solo las asignadas | — |

Con la empresa **bloqueada**, todas las acciones de escritura de esta
tabla quedan deshabilitadas. Ver
[30-comercial.md](./30-comercial.md) §3.
