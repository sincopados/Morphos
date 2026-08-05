# Dashboard de empresa — reglas de negocio

Glosario: [Operación](../../contexts/operacion/CONTEXT.md).

Alcance: el dashboard es **por empresa**, nunca consolidado entre
empresas. El `owner` ve el dashboard de la empresa que tenga
seleccionada, con todas sus obras; si es dueño de varias, cambia con el
selector y el dashboard se recalcula por completo. Si la empresa tiene
varios `owner`, todos ven exactamente lo mismo. El `administrador` ve
solo las obras que el `owner` le asignó. `morphos_core` puede ver el
dashboard de cualquier empresa.

## 1. Bloques obligatorios

1. **Generado en la semana** — total ingresado por la empresa en la
   semana en curso, sumando todas las obras. Semana = lunes a domingo
   en la zona horaria de la empresa. Muestra comparativa contra la
   semana anterior.
2. **Tareas pendientes por obra** — listado por obra con el número de
   tareas abiertas, destacando las vencidas. Cada obra es una fila; al
   abrirla se ve el detalle.
3. **Cobros generales** — total de cobros de toda la empresa en el
   período seleccionado.
4. **Gastos generales** — total de gastos de toda la empresa en el
   período seleccionado, incluyendo mano de obra, materiales y gastos
   operativos.
5. **Cobros por obra** — desglose por cada obra activa.
6. **Gastos por obra** — desglose por cada obra activa.

## 2. Reglas de cálculo

- **Criterio de caja.** Un cobro solo suma cuando el pago está
  confirmado; mientras tanto queda como pendiente de cobro. Una venta
  registrada no es un cobro.
  *(MORPHOS se mide a sí misma por devengo, no por caja — la asimetría
  es deliberada y está justificada en
  [ADR-0001](../adr/0001-membresia-prepago-con-bloqueo.md).)*
- **Margen por obra** = cobros por obra − gastos por obra. Admite
  valores negativos.
- Los totales generales deben cuadrar exactamente con la suma de los
  desgloses por obra; los movimientos no asignados se agrupan en la
  obra virtual "General / Empresa".
- Período por defecto: semana en curso. Selector para mes en curso y
  rango personalizado; el bloque "Generado en la semana" siempre es
  semanal, sin importar el selector.
- Solo se contabilizan registros confirmados. Los registros modificados
  bajo las reglas de la ventana de 72 h recalculan el dashboard y
  quedan auditados.
- Obras cerradas o archivadas no aparecen en los desgloses activos,
  pero sí siguen contando en los totales históricos del período.

## 3. Visibilidad por rol

| Rol | Qué ve del dashboard |
|---|---|
| `morphos_core` | Cualquier empresa, con alcance total y siempre auditado |
| `owner` | Todos los bloques, toda la empresa y todas sus obras |
| `administrador` | Los mismos bloques, limitados a sus obras asignadas |
| `trabajador` / `vendedor` / `afiliado` | No accede al dashboard; solo su propio saldo y sus registros |

## 4. Comportamiento con la empresa bloqueada

Si la membresía venció sin pago, la empresa queda **bloqueada** y el
dashboard deja de ser accesible para `owner` y `administrador`, que ven
en su lugar la pantalla de renovación. Los datos permanecen intactos y
el dashboard vuelve tal cual estaba en cuanto se paga. Ver
[30-comercial.md](./30-comercial.md) §3.
