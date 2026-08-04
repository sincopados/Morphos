# MORPHOS — Especificación Técnica: Motor de Saldo y Confirmación
### Módulo: Workforce + Ventas/Afiliados (MVP)
### Versión 1.0 — Piloto: SmartPainting (NY)

---

## 0. Principio de diseño (léase antes de programar)

Este módulo NO son tres features separadas (asistencia, ventas, afiliados).
Es **un solo motor**: un evento genera valor → queda `pendiente` → la
cuenta maestra (dueño o admin delegado) confirma → se acredita a un saldo.
Todo lo que sigue está construido sobre esa idea. No dupliques lógica de
confirmación por módulo — todos usan `ledger_entries`.

Reglas de negocio no-negociables:
1. Quien genera el registro (trabajador, vendedor, afiliado) **nunca**
   puede confirmarlo.
2. Solo confirma la **cuenta maestra** (dueño / admin delegado). MORPHOS
   puede confirmar únicamente como servicio de supervisión contratado,
   nunca por defecto.
3. Las reglas de cumplimiento legal (salario mínimo, horas extra) son
   **informativas, jamás bloqueantes**. Se muestran, se registran, no
   impiden guardar.
4. Después de 72 horas de confirmado un registro, no se permite
   modificarlo salvo solicitud formal del dueño con motivo — y esa
   solicitud queda auditada.

---

## 1. Entidades principales

### 1.1 `companies`
Empresa cliente (ej. SmartPainting).

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| name | text | |
| country | text | ISO 3166 |
| region | text | estado/provincia — clave para compliance (ej. "NY") |
| city | text | |
| industry_category | enum/text | ver §4 Onboarding |
| business_need | text[] | ej. ['gestion_personal','ventas','afiliados'] |
| plan | enum | free \| basic \| pro \| enterprise |
| referral_code | text unique | código propio de la empresa para referir usuarios a MORPHOS |
| referred_by_code | text nullable | si esta empresa llegó por referido de otra |
| created_at | timestamptz | |

### 1.2 `users`
Cualquier persona dentro del sistema (trabajador, vendedor, afiliado, admin, dueño).

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| company_id | uuid FK nullable | null si es afiliado a nivel plataforma MORPHOS, no de una empresa |
| role | enum | `owner` \| `admin_delegado` \| `trabajador` \| `vendedor` \| `afiliado` \| `tutor` \| `asesor` \| `morphos_core` |
| profile_type | enum | `con_horario` \| `sin_horario` — determina si usa check-in de bloques o solo eventos de venta |
| full_day_value | numeric nullable | valor que el dueño asigna a un día completo (8h) |
| half_day_value | numeric nullable | valor de medio día (4h) |
| pay_period | enum | semanal \| quincenal \| mensual |
| status | enum | activo \| inactivo | |
| created_at | timestamptz | |

> Nota: `owner` y `admin_delegado` son los únicos roles con permiso de
> `confirm` en `ledger_entries`. Ver matriz de permisos en §3.

### 1.3 `ledger_entries` — el núcleo del sistema

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| company_id | uuid FK | |
| origin_user_id | uuid FK → users | quien generó el valor |
| scope | enum | `platform` (MORPHOS acredita, ej. referidos) \| `company` (la empresa acredita a su gente) |
| type | enum | `work_full_day` \| `work_half_day` \| `extra` \| `deduccion` \| `venta` \| `afiliacion` \| `referido` |
| amount | numeric | monto acreditado o a acreditar |
| hours_reported | numeric nullable | 8, 4, o null si es evento de venta — usado solo para la alerta de compliance, no para el cálculo del pago |
| status | enum | `pendiente` \| `confirmado` \| `rechazado` |
| confirmed_by | uuid FK nullable → users | debe tener role owner/admin_delegado/morphos_core |
| confirmed_at | timestamptz nullable | |
| period_ref | text | ej. "2026-W31" o "2026-08" según pay_period del usuario, para agregación de saldo |
| metadata | jsonb | detalle libre: nombre del producto vendido, cliente, notas |
| created_at | timestamptz | |

**Regla de integridad crítica:** `confirmed_by != origin_user_id` siempre.
Aplícala como constraint a nivel de aplicación Y como trigger a nivel de
base de datos — no confíes solo en la lógica del backend.

### 1.4 `compliance_rules`
Reglas de referencia, no ejecutables como bloqueo — solo generan alertas.
**Actualizado (v1.1):** generalizada a filas por tipo de regla en vez de
columnas fijas — NY tiene una sola regla de horas extra, pero Colombia
tiene niveles distintos (diurna, nocturna, dominical/festivo) que no
caben en un solo `overtime_multiplier`. Ver `morphos_fase_0_5_schema_v1.sql`
para la implementación exacta.

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| jurisdiction | text | ej. "US-NY", "CO-MED" |
| rule_type | enum | min_wage \| overtime_day \| overtime_night \| sunday_holiday |
| currency | text | ISO 4217 — NY usa USD, Medellín usa COP, no asumir una sola moneda |
| base_value | numeric | valor hora ordinaria o de referencia |
| threshold_hours_week | numeric nullable | ej. 40 (NY) o 42 (Colombia) |
| surcharge_percentage | numeric nullable | ej. 50 (NY 1.5x), 25/75/90 (Colombia por tipo) |
| effective_from | date | las reglas cambian cada año — versiona, no sobrescribas |
| source_url | text | trazabilidad de dónde salió el dato |

### 1.5 `compliance_alerts`
Registro de que se informó — esto es lo que te protege legalmente.

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| ledger_entry_id | uuid FK nullable | |
| user_id | uuid FK | trabajador afectado |
| rule_id | uuid FK → compliance_rules | |
| implied_hourly_rate | numeric | calculado a partir de amount/hours_reported |
| shown_to | uuid FK → users | quien vio la alerta (owner/admin) |
| shown_at | timestamptz | |
| acknowledged | boolean default false | |

### 1.6 `modification_requests`
Auditoría de cualquier cambio después de confirmado.

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| ledger_entry_id | uuid FK | |
| original_snapshot | jsonb | copia exacta del registro antes del cambio |
| new_values | jsonb | |
| within_72h_window | boolean | calculado automático |
| reason | text | obligatorio si `within_72h_window = false` |
| requested_by | uuid FK → users | debe ser `owner` |
| approved_by | uuid FK nullable | owner mismo, o `morphos_core` si es soporte |
| status | enum | pendiente \| aprobado \| rechazado |
| created_at | timestamptz | |

### 1.7 `referral_rewards`
Para el crecimiento de MORPHOS vía empresas y afiliados.

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| referral_code | text FK → companies.referral_code o users (afiliados plataforma) | |
| referred_entity_id | uuid | empresa o usuario nuevo que se registró con ese código |
| reward_type | enum | tokens \| premio_especial | |
| reward_amount | numeric | |
| status | enum | pendiente \| otorgado | |
| created_at | timestamptz | |

---

## 2. Cálculo de saldo en tiempo real (vista del usuario)

No se almacena un "saldo" como campo fijo — se calcula:

```sql
SELECT SUM(amount)
FROM ledger_entries
WHERE origin_user_id = :user_id
  AND status = 'confirmado'
  AND period_ref = :periodo_actual;
```

Esto evita inconsistencias (nunca hay un número "guardado" que se
desincronice del historial real). Para performance a escala, se puede
materializar con un job nocturno, pero el MVP no lo necesita.

---

## 3. Matriz de permisos

| Acción | owner | admin_delegado | trabajador | vendedor/afiliado/tutor/asesor | morphos_core |
|---|---|---|---|---|---|
| Crear ledger_entry (propio) | — | — | ✅ | ✅ | — |
| Confirmar ledger_entry | ✅ | ✅ | ❌ | ❌ | Solo si contratado como supervisión |
| Ver saldo propio | ✅ | ✅ | ✅ | ✅ | — |
| Ver saldo de otros | ✅ (todos) | ✅ (los que gestiona) | ❌ | ❌ | Solo soporte, auditado |
| Solicitar modificación >72h | ✅ | ❌ | ❌ | ❌ | ✅ (con auditoría) |

---

## 4. Onboarding — identificación automática de mercado/necesidad

Al registro gratuito/básico, capturar (todo va a `companies`):

1. **Nombre de la empresa** → `name`
2. **Ubicación** (país/región/ciudad) → determina qué fila de
   `compliance_rules` se activa por defecto (crítico: sin esto, no hay
   alertas de compliance correctas)
3. **Categoría de industria** — selección de una taxonomía fija cerrada
   para el MVP (construcción, gastronomía, retail, servicios
   profesionales, belleza, otro). *No uses texto libre + IA para
   clasificar todavía* — eso es una v2. Para el MVP, una lista cerrada
   evita ambigüedad y ya te permite precargar valores sugeridos de
   `full_day_value`/`half_day_value` por industria.
4. **Necesidad principal** (multi-select): gestión de personal / ventas /
   afiliados / las tres → esto determina qué módulos se activan visibles
   en el dashboard desde el día uno (no mostrar Workforce a quien solo
   necesita afiliados, por ejemplo).
5. **Tamaño de equipo** (número) → valida la regla de "más de 1
   trabajador" y sugiere si necesita el servicio de supervisión a
   distancia de MORPHOS.

El resultado de estos 5 campos = la semilla del `Company DNA` (aún no
es aprendizaje automático — es configuración inicial correcta, que
luego el sistema sí empieza a ajustar con uso real).

---

## 5. Qué NO construir todavía (para no sobre-ingenierizar el MVP)

- Clasificación de industria por IA/NLP a partir de texto libre.
- Motor de reglas JSON completamente dinámico (`json-rules-engine`) —
  para el piloto de SmartPainting, `compliance_rules` como tabla simple
  basta. Se migra a motor dinámico cuando haya más de 2-3 jurisdicciones.
- Cálculo automático de nómina real o integración con procesadores de
  pago — el MVP solo sugiere y acredita saldo interno.
