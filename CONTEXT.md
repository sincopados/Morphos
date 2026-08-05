# MORPHOS — este documento se ha dividido

El antiguo documento maestro mezclaba tres cosas: glosario, reglas de
negocio y esquema de datos. Ahora están separadas.

Empieza por **[CONTEXT-MAP.md](./CONTEXT-MAP.md)**.

## Glosarios — qué significa cada palabra

- [contexts/operacion/CONTEXT.md](./contexts/operacion/CONTEXT.md) —
  obras, gente y dinero **entre una empresa y sus clientes finales**.
- [contexts/comercial/CONTEXT.md](./contexts/comercial/CONTEXT.md) —
  membresías y dinero **entre MORPHOS y las empresas**.

## Especificación — cómo funciona

- [docs/spec/00-vision.md](./docs/spec/00-vision.md) — qué es MORPHOS y
  la identidad de marca.
- [docs/spec/10-empresas-y-usuarios.md](./docs/spec/10-empresas-y-usuarios.md)
  — cardinalidad, roles, perfiles, pertenencias, auditoría.
- [docs/spec/20-dashboard-empresa.md](./docs/spec/20-dashboard-empresa.md)
  — bloques y reglas de cálculo del dashboard del `owner`.
- [docs/spec/30-comercial.md](./docs/spec/30-comercial.md) —
  membresía prepago, estados de empresa, bloqueo, soporte y egresos.
- [docs/spec/40-dashboard-global.md](./docs/spec/40-dashboard-global.md)
  — el Dashboard Global de `morphos_core` y sus subpáginas.
- [docs/spec/50-obras.md](./docs/spec/50-obras.md) — el módulo de obras
  al completo.

## Decisiones y su porqué

- [ADR-0001](./docs/adr/0001-membresia-prepago-con-bloqueo.md) —
  membresía prepago mensual con bloqueo, sin mora.
- [ADR-0002](./docs/adr/0002-morphos-core-rol-global-excluyente.md) —
  `morphos_core` como rol global y excluyente.
- [ADR-0003](./docs/adr/0003-dos-contextos-operacion-y-comercial.md) —
  dos contextos delimitados con vocabularios disjuntos.
