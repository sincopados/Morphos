---
status: accepted
---

# `morphos_core` es un rol global y excluyente

En MORPHOS el rol es un atributo de la relación usuario↔empresa: la
misma persona es `owner` en una empresa y `trabajador` en otra.
`morphos_core` rompe esa regla a propósito — es un rol **global**, no
cuelga de ninguna empresa, y es **incompatible con cualquier
pertenencia**. Quien tiene `morphos_core` no puede ser `owner` de nada.

Elegimos la exclusión en lugar de permitir el solapamiento para
eliminar el conflicto de interés de raíz: un `owner` que además fuera
`morphos_core` podría entrar al Dashboard Global y modificar los
registros económicos de su propia empresa saltándose la ventana de
72 horas, sin que la auditoría pudiera distinguir si actuó como soporte
o como parte interesada.

## Consecuencias

- **No puedes contratar para el equipo interno a alguien que sea dueño
  de una empresa cliente.** Es una restricción real de contratación, no
  solo un detalle técnico.
- **Riesgo de lockout total.** Si el sistema se quedara sin ninguna
  cuenta `morphos_core`, ningún `owner` podría recuperarlo: el rol es
  global y excluyente, y no hay ruta de escalada desde dentro del
  producto. Se mitiga con una **cuenta raíz** que ningún `morphos_core`
  puede eliminar ni degradar, ni siquiera ella misma.
- La cuenta raíz es, por diseño, el objetivo más valioso del sistema si
  alguien intenta comprometerlo. Debe protegerse en consecuencia.

## Alternativas descartadas

- **Rol global que convive con las pertenencias**, auditando el
  contexto desde el que se actúa y marcando el conflicto de interés en
  el historial. Más flexible, pero deja el conflicto existiendo y
  confía en que alguien revise la auditoría después.
- **Empresa virtual "MORPHOS"** de la que el equipo interno es
  pertenencia. Reutiliza el modelo sin tocarlo, a costa de una empresa
  fantasma que aparece en todo conteo de empresas y hay que excluir a
  mano en cada consulta.
- **Invariante de ≥ 1 `morphos_core`** en lugar de cuenta raíz. Resuelve
  el lockout sin cuenta privilegiada permanente, pero deja la garantía
  repartida entre cuentas que van y vienen.
