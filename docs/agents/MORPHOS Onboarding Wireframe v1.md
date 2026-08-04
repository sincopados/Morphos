# MORPHOS — Wireframe Conceptual: Flujo de Onboarding
### Piloto de referencia: SmartPainting (NY) · Válido para cualquier empresa

Principio del flujo: cada pantalla captura solo lo necesario para generar
el `Company DNA` inicial (ver Spec v1, §4). Nada de formularios largos —
6-7 pantallas cortas, una decisión por pantalla.

---

## Pantalla 1 — Crear cuenta

```
┌─────────────────────────────────┐
│  MORPHOS                        │
│  Construye. Automatiza. Escala. │
│                                  │
│   ┌───────────────────────┐     │
│   │  G  Continuar con      │     │
│   │     Google              │     │
│   └───────────────────────┘     │
│                                  │
│  ── o registra con correo ──    │
│                                  │
│  Nombre de la empresa           │
│  [_______________________]      │
│                                  │
│  Correo                         │
│  [_______________________]      │
│                                  │
│  Contraseña                     │
│  [_______________________]      │
│                                  │
│  ¿Tienes un código de           │
│  referido? (opcional)           │
│  [____]                         │
│                                  │
│         [ Crear cuenta ]        │
└─────────────────────────────────┘
```
**Datos capturados:** `companies.name`, credenciales del `owner`,
`companies.referred_by_code` (si aplica → dispara `referral_rewards`
pendiente al confirmarse el registro).

**Registro con Google (OAuth 2.0):** reduce fricción del primer paso —
el dueño no crea contraseña, MORPHOS recibe nombre y correo verificado
directamente de Google. Sigue pidiendo `companies.name` porque Google
no lo provee. Internamente, ambos caminos (Google o correo/contraseña)
crean el mismo registro `users` con `role = owner` — el método de
autenticación es un detalle de la capa de Auth, no cambia el modelo de
datos ni las pantallas siguientes (2 en adelante son idénticas para
ambos casos).

---

## Pantalla 2 — Ubicación (define jurisdicción de compliance)

```
┌─────────────────────────────────┐
│  ¿Dónde opera tu negocio?       │
│                                  │
│  País                           │
│  [ Estados Unidos      ▾]       │
│                                  │
│  Estado/Región                  │
│  [ New York             ▾]      │
│                                  │
│  Ciudad                         │
│  [_______________________]      │
│                                  │
│         [ Continuar ]           │
└─────────────────────────────────┘
```
**Lógica:** país+región → `jurisdiction` en `compliance_rules`
(`US-NY` o `CO-MED`). Si la combinación no existe todavía en la tabla,
mostrar aviso: *"Estamos activando tu jurisdicción — el equipo de
MORPHOS te confirma en menos de 24h"* en vez de fallar silenciosamente.

---

## Pantalla 3 — Categoría de industria (lista cerrada)

```
┌─────────────────────────────────┐
│  ¿A qué se dedica tu empresa?   │
│                                  │
│  ○ Construcción/Pintura         │
│  ○ Gastronomía                  │
│  ○ Retail                       │
│  ○ Servicios profesionales      │
│  ○ Belleza y bienestar          │
│  ○ Otro: [___________]          │
│                                  │
│         [ Continuar ]           │
└─────────────────────────────────┘
```
**Lógica:** precarga valores sugeridos de `full_day_value`/
`half_day_value` según industria (editable siempre por el dueño — son
solo un punto de partida, no una regla fija).

---

## Pantalla 4 — Necesidad principal (multi-select)

```
┌─────────────────────────────────┐
│  ¿Qué necesitas gestionar?      │
│  (elige todas las que apliquen) │
│                                  │
│  ☐ Personal / asistencia        │
│  ☐ Ventas                       │
│  ☐ Afiliados / referidos        │
│                                  │
│         [ Continuar ]           │
└─────────────────────────────────┘
```
**Lógica:** determina qué módulos aparecen visibles en el dashboard
desde el día 1 (`companies.business_need`). No mostrar Workforce a
quien solo marcó Afiliados, por ejemplo.

---

## Pantalla 5 — Tamaño de equipo (regla de negocio activa aquí)

```
┌─────────────────────────────────┐
│  ¿Cuántas personas trabajan      │
│  contigo (sin contarte a ti)?   │
│                                  │
│  [   ___   ]                    │
│                                  │
│  ¿Tienes alguien que pueda      │
│  confirmar horarios/ventas      │
│  todos los días?                │
│  ○ Sí, yo mismo                 │
│  ○ Sí, tengo un administrador   │
│  ○ No estoy seguro              │
│                                  │
│         [ Continuar ]           │
└─────────────────────────────────┘
```
**Lógica de bifurcación:**
- Si equipo = 0 → bloquear onboarding: *"MORPHOS está diseñado para
  equipos de 2 o más personas"* + opción de lista de espera.
- Si responde "No estoy seguro" en la pregunta de confirmación →
  mostrar oferta del **servicio de supervisión a distancia de MORPHOS**
  antes de continuar (este es el momento exacto de venta de ese
  servicio, no después).

---

## Pantalla 6 — Resumen del Company DNA generado

```
┌─────────────────────────────────┐
│  Esto configuramos para ti:     │
│                                  │
│  Jurisdicción: US-NY            │
│  Industria: Construcción        │
│  Día completo sugerido: $XXX    │
│  Medio día sugerido: $XX        │
│  Módulos activos: Personal,     │
│  Ventas                         │
│                                  │
│  Puedes cambiar todo esto       │
│  después.                       │
│                                  │
│      [ Confirmar y crear ]      │
└─────────────────────────────────┘
```
Este es el momento donde se crea `companies` en firme y se activa el
`plan = free`.

---

## Pantalla 7 — Invitar al primer equipo

```
┌─────────────────────────────────┐
│  Invita a tu equipo             │
│                                  │
│  Nombre: [____________]         │
│  Rol: [ Trabajador      ▾]      │
│       (Trabajador / Vendedor /  │
│        Afiliado / Admin         │
│        delegado)                │
│  Perfil: [ Con horario   ▾]     │
│       (Con horario / Sin        │
│        horario)                 │
│                                  │
│  [ + Agregar otra persona ]     │
│                                  │
│         [ Finalizar ]           │
└─────────────────────────────────┘
```
**Nota:** no es obligatoria — el dueño puede saltarla y hacerlo después
desde el dashboard, pero dejarla en el onboarding aumenta la
probabilidad de que la cuenta se use de inmediato en vez de quedar
abandonada tras el registro.

---

## Pantalla 8 — Dashboard inicial (destino final)

Muestra únicamente los módulos marcados en Pantalla 4. Si eligió
"Personal" → panel de check-ins pendientes de confirmar. Si eligió
"Ventas/Afiliados" → panel de ventas pendientes de confirmar. Ambos
alimentan la misma tabla `ledger_entries` — la UI simplemente filtra
por `type`.

---

## Resumen de bifurcaciones críticas para el desarrollador

| Condición | Resultado |
|---|---|
| `team_size = 0` | Bloquea onboarding, ofrece lista de espera |
| `confirmador = "No estoy seguro"` | Ofrece supervisión a distancia MORPHOS |
| Jurisdicción sin fila en `compliance_rules` | No bloquea — crea la cuenta, marca `compliance_pending = true`, notifica al equipo interno |
| `referred_by_code` presente | Crea `referral_rewards` en estado `pendiente`, se otorga cuando la empresa complete el onboarding completo (no solo el registro) |
