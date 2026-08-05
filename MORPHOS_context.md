# MORPHOS — context.md
### Documento maestro de contexto del proyecto
### Última actualización: 4 de agosto, 2026

---

## 1. Qué es MORPHOS

Sistema Operativo Empresarial Adaptativo (Adaptive Business Operating
System). No es un ERP con IA encima ni un SaaS de RRHH — es un sistema
que aprende cómo funciona cada empresa, coordina personas, procesos y
motores de inteligencia artificial, y ayuda a las empresas a operar
mejor cada día. Principio rector: **la inteligencia propone, el
humano decide** (autonomía supervisada).

---

## 2. Empresas y obras

### 2.1 Cardinalidad (regla base del modelo)

- **Una empresa tiene muchas obras.** Una obra pertenece siempre a una
  sola empresa; no se comparten obras entre empresas.
- **Un dueño puede tener varias empresas.** La cuenta de `owner` no
  está atada a una única empresa: una misma persona puede crear y
  administrar N empresas, y cambia entre ellas con un selector de
  empresa. Cada empresa mantiene sus datos, usuarios y contabilidad
  completamente separados.
- **Una empresa puede tener uno o más dueños.** Se admiten varios
  `owner` sobre la misma empresa (socios), todos con el mismo alcance
  total sobre ella. Uno de ellos queda marcado como **titular de la
  suscripción** — el que paga —, y esa es la única diferencia entre
  ellos.
- En resumen: `owner` ↔ `empresa` es una relación **muchos a muchos**;
  `empresa` → `obra` es **uno a muchos**.

### 2.2 Definiciones

- **Empresa** — unidad raíz del sistema. Agrupa a todos sus usuarios,
  obras y movimientos económicos. Los datos nunca cruzan de una empresa
  a otra, ni siquiera entre empresas del mismo dueño.
- **Obra** — unidad operativa dentro de una empresa (proyecto, sitio,
  cliente o centro de coste, según la industria). Es el nivel al que se
  asignan administradores, tareas, cobros y gastos, y el eje de todos
  los desgloses del dashboard (sección 4).
- Estados de una obra: `activa`, `cerrada`, `archivada`. Solo las
  activas aparecen en los desgloses operativos del dashboard.
- Los movimientos que no pertenecen a ninguna obra concreta (gastos de
  estructura, cobros generales) se imputan a la obra virtual
  **"General / Empresa"**, que existe siempre y no se puede borrar.

---

## 3. El sistema de usuarios — completo

### 3.1 Roles (`user_role`)

| Rol | Quién es | Alcance |
|---|---|---|
| `owner` | Dueño del negocio, cuenta maestra. Puede haber más de uno por empresa, y una misma persona puede ser `owner` de varias empresas | Toda la empresa (o empresas) de la que es dueño, con todas sus obras |
| `administrador` | Administrador que el dueño designa y que puede gestionar todo en cada obra asignada por el owner | Las obras que tiene asignadas |
| `trabajador` | Persona con horario fijo (asistencia por bloques) | hace cheking de entrada y salida, genera sus partes de trabajo, solo ve su propio saldo |
| `vendedor` | Genera ventas para la empresa a la que pertenece | Solo genera ventas para la empresa a la que pertenece, ve su propio saldo |
| `afiliado` | Genera referidos/comisiones para la empresa a la que pertenece, sin horario | Solo genera ventas para la empresa a la que pertenece, ve su propio saldo |
| `morphos_core` | Equipo interno de MORPHOS (soporte/supervisión contratada) | SUPER Admin de todo el sistema y sus empresas |

### 3.2 Perfiles (`profile_type`)

- **`con_horario`** — usa check-in de bloques de tiempo (día
  completo = 8h, medio día = 4h, más una casilla opcional de
  extra/deducción). Aplica a `trabajador`.
- **`sin_horario`** — no hace check-in de tiempo; genera un registro
  cada vez que ocurre un evento (una venta, un referido, un servicio
  prestado). Aplica a `vendedor`, `afiliado`, `tutor`, `asesor`.

### 3.3 Pertenencia a empresa y asignación a obras

- `trabajador`, `vendedor`, `afiliado` y `administrador` pertenecen a
  **una sola empresa**. `morphos_core` es transversal a todas, y el
  `owner` puede estar en varias (sección 2.1).
- El `owner` asigna a cada `administrador` una o varias obras de esa
  empresa; fuera de ellas no ve datos ni puede operar.
- `trabajador`, `vendedor` y `afiliado` ven únicamente sus propios
  registros y su propio saldo, nunca los totales de la empresa ni de la
  obra.
- Toda acción sobre un registro económico queda auditada con usuario,
  fecha y obra afectada.

### 3.4 Autenticación

Dos caminos, mismo modelo de datos al final: **Google OAuth** o
**correo/contraseña**.

### 3.5 Modificación de registros después de confirmados

- Ventana de 72 horas: el `owner` puede modificar libremente.
- Después de 72 horas: requiere solicitud formal con motivo,
  registrada en `modification_requests`, visible para el usuario
  afectado si hay disputa.
- `morphos_core` puede modificar como soporte, siempre auditado igual
  que el dueño.

---

## 4. Dashboard de empresas registradas — reglas de negocio

Alcance: el dashboard es **por empresa**, nunca consolidado entre
empresas. El `owner` ve el dashboard de la empresa que tenga
seleccionada, con todas sus obras; si es dueño de varias, cambia de
empresa con el selector y el dashboard se recalcula por completo. Si la
empresa tiene varios `owner`, todos ven exactamente lo mismo. El
`administrador` ve solo las obras que el `owner` le asignó.
`morphos_core` puede ver el dashboard de cualquier empresa.

### 4.1 Bloques obligatorios del dashboard del `owner`

1. **Generado en la semana** — total facturado/ingresado por la empresa
   en la semana en curso, sumando todas las obras. Semana = lunes a
   domingo en la zona horaria de la empresa. Muestra comparativa contra
   la semana anterior.
2. **Tareas pendientes por obra** — listado por obra con el número de
   tareas abiertas (no completadas), destacando las vencidas. Cada obra
   es una fila; al abrirla se ve el detalle de sus tareas.
3. **Cobros generales** — total de cobros (dinero efectivamente
   recibido) de toda la empresa en el período seleccionado.
4. **Gastos generales** — total de gastos de toda la empresa en el
   período seleccionado, incluyendo nómina, materiales y gastos
   operativos.
5. **Cobros por obra** — desglose de cobros por cada obra activa.
6. **Gastos por obra** — desglose de gastos por cada obra activa.

### 4.2 Reglas de cálculo

- **Cobro ≠ venta**: una venta registrada solo suma a "cobros" cuando
  el pago está confirmado; mientras tanto queda como pendiente de cobro.
- **Margen por obra** = cobros por obra − gastos por obra. Se muestra
  junto a cada obra y admite valores negativos (obra en pérdida).
- Los totales generales deben cuadrar exactamente con la suma de los
  desgloses por obra; los movimientos no asignados a ninguna obra se
  agrupan en una obra virtual "General / Empresa".
- Período por defecto: semana en curso. Selector para mes en curso y
  rango personalizado; el bloque "Generado en la semana" siempre es
  semanal, sin importar el selector.
- Solo se contabilizan registros confirmados. Los registros modificados
  bajo las reglas de la sección 3.5 recalculan el dashboard y quedan
  auditados.
- Obras cerradas o archivadas no aparecen en los desgloses activos,
  pero sí siguen contando en los totales históricos del período.

### 4.3 Visibilidad por rol

| Rol | Qué ve del dashboard |
|---|---|
| `owner` | Todos los bloques, toda la empresa y todas sus obras |
| `administrador` | Los mismos bloques, limitados a sus obras asignadas |
| `trabajador` / `vendedor` / `afiliado` | No accede al dashboard; solo su propio saldo y sus registros |
| `morphos_core` | Cualquier empresa, en modo soporte y siempre auditado |

---

## 5. Módulo de Obras

Referencia funcional: Jobber (pantalla de *Job*). MORPHOS adapta ese
modelo, con una diferencia estructural: **la mano de obra no se teclea
a mano — se deriva del sistema de check-in de cada trabajador**
(sección 3.2, perfil `con_horario`).

### 5.1 Entidad `obras`

Cabecera de la obra, equivalente a la ficha superior del Job.

| Campo | Tipo | Origen / notas |
|---|---|---|
| `id` | uuid | |
| `empresa_id` | fk → `empresas` | Una obra pertenece a una sola empresa (sección 2.1) |
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
| `creado_por`, `created_at`, `updated_at` | | Auditoría (sección 3.5) |

**Estado `atrasada`**: se calcula, no se teclea — una obra está atrasada
cuando tiene visitas o tareas vencidas sin completar, o pasó
`fecha_fin` sin estar completada.

### 5.2 `obra_lineas` — Producto / Servicio

Equivale a la tabla *Product / Service*. Es el precio pactado con el
cliente, no el coste real.

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

### 5.3 Mano de obra — **derivada del check-in**

En Jobber la tabla *Labor* se llena a mano. En MORPHOS **no existe alta
manual de horas**: cada fila es la proyección de un registro de
check-in del trabajador.

- Fuente: los check-in de bloques (día completo = 8 h, medio día = 4 h,
  más extra/deducción opcional) del perfil `con_horario`.
- El trabajador, al hacer check-in, selecciona **a qué obra** imputa el
  bloque. Sin obra, el bloque cae en "General / Empresa" (sección 2.2).
- Vista por fila: trabajador, notas, fecha, hora de entrada y salida,
  duración, coste. Totales al pie (p. ej. 120 h → $3.483,04) y
  paginación.
- `coste_mano_obra = horas × tarifa_hora del trabajador` vigente en la
  fecha del bloque. La tarifa se versiona: cambiarla hoy no reescribe
  el coste de obras pasadas.
- Solo suman los bloques **confirmados**. Un bloque pendiente de
  aprobación aparece marcado y no entra en el coste.
- Correcciones: se ajusta el registro de check-in origen, bajo la
  ventana de 72 h de la sección 3.5. La obra se recalcula sola.

### 5.4 `obra_gastos` — Expenses

Gastos directos imputados a la obra: materiales, alquiler de equipo,
vertedero, subcontratas.

| Campo | Notas |
|---|---|
| `obra_id`, `fecha`, `concepto`, `categoria` | |
| `importe`, `proveedor` | |
| `comprobante_id` | fk → `archivos` (foto/PDF del ticket) |
| `registrado_por` | usuario que lo dio de alta |
| `estado` | `pendiente` \| `confirmado` — solo los confirmados suman |

### 5.5 `obra_visitas` — Scheduled visits

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

### 5.6 Tareas

Las tareas pendientes por obra que alimentan el bloque 2 del dashboard
(sección 4.1) viven aquí: `obra_tareas` con `obra_id`, `titulo`,
`asignado_a`, `fecha_limite`, `estado` (`abierta`, `en_curso`,
`completada`) y `prioridad`. Una visita vencida cuenta como tarea
vencida de esa obra.

### 5.7 Facturación y cobros

Bloque *Billing* de la ficha.

- `recordatorios` — configuración de cuándo avisar (p. ej. "cuando la
  obra se marque como cerrada").
- `facturas` (fk `obra_id`, `cliente_id`): número, fecha de
  vencimiento, estado (`proxima`, `enviada`, `vencida`, `pagada`),
  asunto, total, saldo.
- Una factura puede agrupar **varias obras del mismo cliente**: al
  facturar se listan las obras con importe *no facturado* y subtotal, y
  el usuario elige cuáles incluir. Depósitos y descuentos ya cobrados
  se restan automáticamente.
- `cobros` (fk `factura_id` u `obra_id`): fecha, importe, método,
  tipo (`deposito` \| `pago` \| `pago_final`). **Solo los cobros
  confirmados suman al dashboard** (sección 4.2).

### 5.8 Panel económico de la obra

Réplica del panel lateral "Total cost to date", calculado siempre en
vivo:

- **Ingresos** = suma de `obra_lineas.total` (precio pactado).
- **Coste** = mano de obra derivada del check-in (5.3) + gastos
  confirmados (5.4).
- **Beneficio** = ingresos − coste, con su porcentaje.
- **Actividad reciente** — últimos eventos de la obra ("eberg registró
  8 h de trabajo, hace 3 h").
- **Notas internas** — visibles para `owner` y `administrador`
  asignado; nunca para el cliente.

### 5.9 Enlace con el dashboard (sección 4)

- *Cobros por obra* = suma de `cobros` confirmados de la obra.
- *Gastos por obra* = mano de obra (5.3) + `obra_gastos` confirmados.
- *Generado en la semana* = cobros confirmados de todas las obras en la
  semana en curso.
- *Tareas pendientes por obra* = `obra_tareas` abiertas + visitas
  vencidas.

### 5.10 Permisos

| Acción | `owner` | `administrador` | `trabajador` | `vendedor` |
|---|---|---|---|---|
| Crear / editar obra | Sí | Solo sus obras asignadas | No | No |
| Ver panel económico | Sí | Solo sus obras | No | No |
| Registrar horas | — | — | Vía check-in propio | — |
| Alta de gastos | Sí | Sí, en sus obras | No | No |
| Facturar y cobrar | Sí | Según permiso del `owner` | No | No |
| Ver sus visitas/tareas | Sí | Sí | Solo las asignadas | — |

---

## 6. Identidad de marca (resumen)

- Nombre: **MORPHOS**. *(Pendiente: verificación de marca registrada
  — existen otras empresas de tecnología usando nombres muy similares,
  incluyendo "MorphOS" como sistema operativo. No usar en materiales
  legales/contractuales hasta resolver esto.)*
- Colores: Cian Morphos `#00D4FF`, Blanco Sistema `#F5F5F5`, Negro
  Profundo `#0D0D0D`.
- Tagline: "Cerebros digitales que aprenden, mutan y evolucionan."
- Pilares: Aprende, Muta, Confirma, Evoluciona — cada uno corresponde
  a un mecanismo real del sistema (Company DNA, motor de reglas por
  industria, confirmación humana obligatoria, ciclo de mejora con
  datos reales del piloto).

---

