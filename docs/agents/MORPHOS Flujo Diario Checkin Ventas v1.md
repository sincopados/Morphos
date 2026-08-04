# MORPHOS — Wireframe Conceptual: Flujo Diario
### Check-in de trabajador (con horario) + Registro de venta/servicio (sin horario) + Confirmación del administrador
### Modelo genérico — aplica a cualquier empresa registrada, cualquier ciudad/país

Principio: la interfaz cambia según `users.profile_type`, nunca según
qué empresa es. Una empresa de pintura en NY y una de servicios en
Medellín usan exactamente el mismo componente — solo cambian las
etiquetas de industria que ya configuró el dueño en el onboarding.

---

## A. Flujo del TRABAJADOR (`profile_type = con_horario`)

### A1 — Pantalla principal del día

```
┌─────────────────────────────────┐
│  Hola, [Nombre]                  │
│  Hoy: martes 28 de julio         │
│                                  │
│  Estado de hoy: Sin marcar       │
│                                  │
│   ┌───────────────────────┐     │
│   │   📷  Escanear QR      │     │
│   │   del día              │     │
│   └───────────────────────┘     │
│                                  │
│  Saldo del período (semanal)    │
│  $XXX acumulado — pendiente     │
│  de confirmar: $XX              │
└─────────────────────────────────┘
```
El QR cambia diario (evita marcar desde fuera del sitio y compartir
captura de pantalla de un día anterior). Se combina con GPS — ver A2.

### A2 — Selección de jornada (tras escanear QR)

```
┌─────────────────────────────────┐
│  ¿Qué jornada trabajaste hoy?   │
│                                  │
│  ○ Día completo (8h) — $XX      │
│  ○ Medio día (4h) — $XX         │
│                                  │
│  ¿Algo adicional? (opcional)    │
│  ○ Extra a favor  ○ Deducción   │
│  Monto: [_____]                 │
│  Motivo: [_______________]      │
│                                  │
│         [ Registrar ]           │
└─────────────────────────────────┘
```
**Al enviar:** crea `ledger_entries` con `status = pendiente`,
`type = work_full_day` o `work_half_day`, y si aplica, una segunda
entrada `type = extra` o `deduccion` vinculada. GPS + timestamp se
guardan en `metadata` (no en un campo aparte — solo sirven para
auditoría si hay una disputa, no para el cálculo del pago).

### A3 — Confirmación visual inmediata (no es lo mismo que "confirmado")

```
┌─────────────────────────────────┐
│   ✓ Registrado                  │
│                                  │
│   Pendiente de confirmación      │
│   por tu administrador           │
│                                  │
│   [ Ver mi historial ]          │
└─────────────────────────────────┘
```
**Importante de UX:** distinguir siempre "registrado" (lo hizo el
trabajador) de "confirmado" (lo aprobó el admin). Usar colores
distintos consistentemente en toda la app — ej. amarillo = pendiente,
verde = confirmado, rojo = rechazado. Esto evita que el trabajador
piense que ya le van a pagar algo que aún no fue aprobado.

### A4 — Historial / calendario mensual

```
┌─────────────────────────────────┐
│  Julio 2026                     │
│                                  │
│  L  M  M  J  V  S  D             │
│           1  2  3  4             │
│  5  6  7  8  9 10 11             │
│ ...                              │
│                                  │
│  🟡 Pendiente  🟢 Confirmado     │
│  🔴 Rechazado                    │
│                                  │
│  Total confirmado este mes: $XXX│
└─────────────────────────────────┘
```

---

## B. Flujo del VENDEDOR/AFILIADO/TUTOR/ASESOR (`profile_type = sin_horario`)

No hay check-in de tiempo — el evento es la venta o el servicio prestado.

### B1 — Pantalla principal

```
┌─────────────────────────────────┐
│  Hola, [Nombre]                  │
│                                  │
│   ┌───────────────────────┐     │
│   │  + Registrar venta /   │     │
│   │    servicio             │     │
│   └───────────────────────┘     │
│                                  │
│  Saldo del período               │
│  $XXX acumulado — pendiente      │
│  de confirmar: $XX               │
└─────────────────────────────────┘
```

### B2 — Registro de venta/servicio

```
┌─────────────────────────────────┐
│  ¿Qué registras?                │
│  ○ Venta  ○ Afiliación/         │
│    Suscripción  ○ Servicio      │
│                                  │
│  Cliente: [______________]      │
│  Producto/Servicio:              │
│  [_____________________]         │
│  Monto: [_______]                │
│  Comprobante (opcional):         │
│  [ 📎 Adjuntar foto/recibo ]     │
│                                  │
│         [ Registrar ]           │
└─────────────────────────────────┘
```
**Al enviar:** crea `ledger_entries` con `type = venta` /
`afiliacion`, `status = pendiente`. El adjunto va a `metadata` (URL de
storage) — sirve como evidencia para el admin al confirmar, no es
obligatorio porque no todas las ventas generan comprobante físico.

### B3 y B4 — mismas pantallas de confirmación pendiente e historial
que A3/A4, mismo sistema de colores. Es el mismo componente de UI,
alimentado por `type = venta/afiliacion` en vez de `work_*`.

---

## C. Panel del ADMINISTRADOR (cuenta maestra) — donde todo converge

### C1 — Bandeja de pendientes (unifica trabajadores y vendedores)

```
┌─────────────────────────────────┐
│  Pendientes por confirmar (7)   │
│                                  │
│  Filtrar: [Todos ▾] [Personal]  │
│           [Ventas]              │
│                                  │
│  🟡 Juan P. — Día completo — $XX│
│     [ ✓ Confirmar ] [ ✕ ]       │
│                                  │
│  🟡 María G. — Venta $XXX        │
│     Cliente: Acme Corp          │
│     [ ✓ Confirmar ] [ ✕ ]       │
│                                  │
│  [ Confirmar todos los visibles]│
└─────────────────────────────────┘
```
**Nota de diseño:** el botón "Confirmar todos" existe para no castigar
con fricción a un dueño con 15 trabajadores — pero cada confirmación
individual dentro del lote se registra por separado en `ledger_entries`
con el mismo `confirmed_by` y `confirmed_at`, nunca como una acción
agregada sin rastro.

### C2 — Al rechazar (obligatorio dar motivo)

```
┌─────────────────────────────────┐
│  Rechazar registro de Juan P.   │
│                                  │
│  Motivo (obligatorio):           │
│  [_______________________]       │
│                                  │
│    [ Cancelar ]  [ Rechazar ]   │
└─────────────────────────────────┘
```
El motivo es obligatorio aquí (a diferencia del registro del
trabajador, donde el motivo de un extra/deducción es opcional) porque
un rechazo afecta directamente el pago de alguien — necesita quedar
justificado desde el día uno, no solo después de 72h como las
modificaciones.

---

## Resumen de reglas de UI para el desarrollador

| Regla | Por qué |
|---|---|
| Un solo componente de "tarjeta de saldo" reutilizado en A1, A4, B1, B4 | Evita mantener 4 versiones de la misma lógica visual |
| Colores de estado (🟡🟢🔴) idénticos en toda la app, sin excepción | El trabajador/vendedor debe reconocer el estado sin leer texto |
| Rechazo siempre pide motivo; registro inicial del trabajador no lo exige | El rechazo afecta el pago de alguien; el registro inicial no bloquea |
| La bandeja del admin (C1) mezcla personal y ventas en una sola vista, filtrable | Es el mismo `ledger_entries` — no separar en pantallas distintas por tipo |
