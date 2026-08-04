# MORPHOS — Workforce/Ventas/Afiliados

Motor único de generación de valor → confirmación → saldo. Un evento (asistencia, venta, afiliación) queda `pendiente` hasta que la cuenta maestra de la empresa lo confirma y se acredita a un saldo.

## Language

**Company DNA**:
Concepto a futuro (Fase 1+) para una entidad que evoluciona con el uso real de una empresa, mutada por comparaciones entre lo sugerido y lo real (ej. nómina). Hoy **no existe como tabla ni campo** — la fila de `companies` más las respuestas del onboarding son solo la "semilla". No construir persistencia para esto en el MVP.
_Avoid_: usar "Company DNA" como sinónimo de la fila `companies` — son cosas distintas (una es estática y actual, la otra evolutiva y futura).

**Compliance pendiente**:
Estado de una empresa cuya jurisdicción (país+región) todavía no tiene una fila activa en `compliance_rules`. Es un estado persistido y explícito (no derivado), porque se consulta en múltiples lugares de la UI y cambia raramente. Mientras está en este estado, la empresa se crea igual (no bloquea el onboarding) pero no recibe alertas de compliance hasta que el equipo interno active su jurisdicción.

**Tutor** (role):
Capacita a las empresas que pertenecen al sistema MORPHOS. Es un rol exclusivo de plataforma: siempre `company_id = null`, nunca pertenece a una empresa cliente específica.
_Gap abierto_: todavía no tiene un `type` propio en `ledger_entries` ni pantalla de registro — hoy comparte la infraestructura de `vendedor`/`afiliado` sin tener semántica propia implementada. Resolver antes de Hito 2.

**Asesor** (role):
Hace ventas y atención al cliente, ya sea para MORPHOS (plataforma) o para una empresa cliente específica. `company_id` distingue el caso: `null` = asesor de MORPHOS, con valor = asesor interno de esa empresa. No requiere campo nuevo — reutiliza `users.company_id` con la misma regla que ya aplica a `afiliado`.
_Gap abierto_: mismo pendiente que `tutor` — sin `type` de ledger ni pantalla propia todavía.

**Solicitud de modificación** (`modification_requests`):
Registro de auditoría de un cambio a un `ledger_entry` ya confirmado. No es un flujo de aprobación por un tercero: el `owner` la solicita y su propio registro como `approved_by` es solo trazabilidad de que él lo autorizó, no una revisión independiente. `morphos_core` aparece como `approved_by` únicamente cuando el owner pide soporte de MORPHOS para ejecutar el cambio por él. El propósito del registro es dejar rastro inmutable de que se rompió la ventana de 72h y por qué — no gobernanza de doble aprobación.

**Referido** (`ledger_entries.type = referido`):
Único mecanismo para recompensas de crecimiento de MORPHOS (empresa o afiliado de plataforma que trae una nueva empresa/usuario). No existe tabla `referral_rewards` separada — ver ADR-0001. `scope = platform`, confirmado por `morphos_core`, con `reward_type`/`reward_amount` en `metadata`.
_Avoid_: "referral_rewards" como tabla — fue eliminada a favor del motor único de ledger.

**Supervisión contratada**:
Servicio comercial por el cual una empresa contrata a MORPHOS para que `morphos_core` pueda confirmar `ledger_entries` en su nombre. Es un estado propio de la empresa (contratado/no contratado, con fecha), no un rol ni un atajo vía `admin_delegado` — permite distinguir en el historial "confirmado por la empresa" de "confirmado por soporte externo contratado". Sin este estado, la regla no-negociable #2 ("MORPHOS confirma solo como servicio contratado, nunca por defecto") no se puede aplicar como constraint real.
_Gap abierto_: falta el campo/tabla que lo registre (ej. `companies.supervision_contracted`) — no existe todavía en el esquema documentado.

**Scope** (`ledger_entries.scope`):
Derivado de `users.company_id` del `origin_user_id`, no un valor libre por tipo de evento: si el usuario pertenece a una empresa (`company_id` con valor), el evento es `scope = company` — un trabajador siempre genera eventos dentro del ámbito de su empresa. Si el usuario es de plataforma (`company_id = null`, ej. afiliado/tutor/asesor de MORPHOS), el evento es `scope = platform`.
_Gap abierto_: `ledger_entries.company_id` está documentado como FK no-nullable, pero un evento `scope = platform` de un usuario sin empresa no tendría `company_id` que poner ahí — falta resolver si ese campo se vuelve nullable o si se usa otro mecanismo para eventos de plataforma.

**Saldo diario**:
La unidad base real de cálculo. Cada `ledger_entry` se ancla a un día concreto (`period_ref` = fecha ISO del día, ej. `"2026-07-28"`, siempre — no semana ni mes). `semanal`/`mensual` no son unidades de cálculo distintas, son solo criterios de *agregación* de días al mostrar saldo o definir cuándo se paga. Esto preserva el detalle de cada movimiento individual sin perderlo en un agregado.
_Avoid_: `period_ref` con formato de semana ISO (`"2026-W31"`) o mes (`"2026-08"`) — ya no aplica, se reemplaza por fecha diaria siempre.

**Pay period** (`users.pay_period`):
Enum real: `diario | semanal | mensual` (la spec original decía `semanal | quincenal | mensual` — `quincenal` no es un caso real de negocio, las empresas pagan diario, semanal o mensual). Solo determina cómo se *agrupan* los días de `ledger_entries` al mostrar el saldo del período, no cómo se guarda cada entrada.
_Avoid_: `quincenal` como valor de `pay_period`.

**Entrada vinculada** (`ledger_entries` extra/deducción → jornada):
Una entrada `type = extra` o `deduccion` que se origina junto a una jornada (`work_full_day`/`work_half_day`) se vincula explícitamente a ella, no solo por compartir usuario y día. Requiere el vínculo explícito porque un mismo usuario puede tener más de un movimiento el mismo día (ej. corrección) y el admin necesita saber sin ambigüedad a cuál jornada pertenece cada extra/deducción al confirmar.
_Gap abierto_: falta el campo (ej. `ledger_entries.related_entry_id uuid nullable`, auto-referencia) — no existe todavía en el esquema documentado.

**Tamaño de equipo** (`team_size`):
Derivado, no persistido — es `COUNT(users WHERE company_id = X)`, igual que el saldo (evita desincronización). No existe como campo en `companies`. La pregunta de la Pantalla 5 del onboarding ("¿cuántas personas trabajan contigo?") es una respuesta transitoria del wizard, usada solo para decidir el bloqueo en ese instante (antes de que existan filas `users`, que se crean recién en Pantalla 7) — no se guarda como campo aparte.

**Industria "Otro"** (`industry_category = 'otro'`):
Es un valor más de la lista cerrada, no una puerta a texto libre clasificable. El campo de texto que lo acompaña en el onboarding (Pantalla 3) es solo una nota descriptiva (ej. `industry_other_note`), sin efecto funcional — nunca se usa para clasificar ni para precargar `full_day_value`/`half_day_value`. Empresas con `industria = otro` no reciben valores sugeridos; el dueño los llena a mano.
_Avoid_: tratar el texto de "Otro" como entrada a un clasificador — eso es explícitamente fuera de alcance del MVP (ver §5 de la spec).

**Sitio/obra**:
Dirección de trabajo asignada a un trabajador, informada de antemano por la empresa. Reemplaza al "QR diario" como unidad de verificación de check-in — ver ADR-0002.

**Check-in con evidencia fotográfica**:
Flujo de asistencia del trabajador (`profile_type = con_horario`): confirma asistencia del día, llega al sitio/obra y toma una **foto de llegada** en el lugar; al finalizar la jornada toma una **foto de salida** mostrando el avance del trabajo realizado. Reemplaza al escaneo de QR diario — ver ADR-0002.
_Avoid_: "QR del día" / "escanear QR" como parte del check-in — eliminado, ver ADR-0002.

**Turno asignado**:
Definición del dueño/admin, por trabajador y por día, de qué jornada se espera (`work_full_day`/`work_half_day`) y en qué sitio/obra. El trabajador no la elige — solo la confirma con foto de llegada y foto de salida. El `type` del `ledger_entry` resultante viene de este turno asignado, no de las horas reales trabajadas.
_Gap abierto_: no existe tabla/entidad documentada para esto (ej. `assigned_shifts`: `user_id`, `date`, `jornada_type`, `sitio`) — falta modelarla antes de Hito 2/4.

**Horas reales de llegada/salida**:
Timestamps reales de la foto de llegada y la foto de salida, capturados en `hours_reported`/`metadata` del `ledger_entry`. Visibles **solo para el administrador** (no para el trabajador) — el trabajador únicamente ve la jornada ya establecida y su saldo acumulado. Se usan igual que siempre para alertas de compliance, nunca para el cálculo del pago (eso lo determina el turno asignado, no las horas reales).

**Bloqueo por rechazos acumulados**:
Contador acumulado por trabajador (no por registro individual) de rechazos a sus `ledger_entries`. Al 2do rechazo se notifica de inmediato al administrador para que se comunique directamente con el trabajador y entienda qué sucede. Al 3er rechazo se bloquea definitivamente la capacidad de check-in de ese trabajador — solo un admin puede desbloquearlo. Todos los roles superiores al trabajador (owner y admin_delegado) se notifican por igual, no solo quien confirmó/rechazó. Si el motivo del rechazo es un error del sistema MORPHOS (no del trabajador), corresponde contactar directamente a soporte, no seguir el flujo de bloqueo.
_Gap abierto_: falta modelar el contador (ej. derivado de `COUNT(ledger_entries WHERE origin_user_id=X AND status='rechazado')`, o persistido) y el estado de bloqueo (ej. `users.checkin_blocked`) — no existen todavía en el esquema documentado.
