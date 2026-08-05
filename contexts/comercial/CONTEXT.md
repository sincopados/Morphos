# Comercial

MORPHOS como negocio: qué le cobra a las empresas que lo usan, qué pasa
cuando dejan de pagar, y cómo el equipo interno supervisa y sostiene el
sistema. Este contexto nunca mira el dinero que las empresas mueven con
sus propios clientes — eso vive en
[Operación](../operacion/CONTEXT.md).

## Language

### Suscripción

**Membresía**:
El derecho de una empresa a operar en MORPHOS durante un ciclo. Es
**una por empresa**: un mismo `owner` con tres empresas paga tres
membresías independientes.
_Avoid_: suscripción, plan, licencia, abono

**Titular**:
El `owner` al que se le factura la membresía de una empresa. Es la
única diferencia entre varios `owner` de la misma empresa.
_Avoid_: pagador, responsable, facturado a

**Ciclo**:
El mes de servicio que cubre una membresía. Se paga **por adelantado**:
no existe servicio prestado y no cobrado.
_Avoid_: período, mes de facturación, billing cycle

**Vencimiento**:
La fecha en que expira el ciclo pagado. Si ese día no hay pago, la
empresa se bloquea sin más plazos.
_Avoid_: caducidad, corte, fecha límite

**Aviso de vencimiento**:
La notificación que sale 7 días naturales antes del vencimiento. Es el
único aviso previo: no hay recordatorios posteriores ni mora.
_Avoid_: recordatorio, alerta previa, dunning

### Estado de una empresa

**Activa**:
Empresa con membresía vigente. Opera con normalidad.
_Avoid_: al día, vigente, en regla

**Bloqueada**:
Empresa cuya membresía venció sin pago. Sus datos quedan intactos y es
**recuperable**: paga y vuelve al instante. Es el embudo de cobro.
_Avoid_: inactiva, suspendida, morosa, impagada

**Dada de baja**:
Empresa que se fue por decisión propia. Sale de los contadores
operativos y solo cuenta como abandono.
_Avoid_: cancelada, cerrada, churned

**Bloqueo**:
El efecto de vencer sin pago: `owner` y `administrador` pierden el
acceso; `trabajador`, `vendedor` y `afiliado` conservan una vista de
solo lectura de su propio saldo. Nadie crea, confirma ni factura.
_Avoid_: suspensión, corte de servicio, freeze

### Dinero de MORPHOS

**Recaudo**:
El dinero que MORPHOS factura por membresías. Se contabiliza por
**devengo** — en el ciclo al que corresponde — no cuando entra en la
cuenta.
_Avoid_: cobro, facturación, ingresos por venta

**Egreso**:
Coste de MORPHOS como negocio: infraestructura, nómina interna,
proveedores, comisiones. Se da de alta a mano.
_Avoid_: gasto, coste operativo

**Neto mensual**:
Recaudo del mes menos egresos del mes. Es la rentabilidad de MORPHOS, y
no tiene ninguna relación con el margen de ninguna obra.
_Avoid_: beneficio, resultado, profit

### Equipo interno

**morphos_core**:
El rol de superadministrador del sistema. Ve y modifica todo, en todas
las empresas, y es **excluyente**: quien lo tiene no puede pertenecer a
ninguna empresa.
_Avoid_: superadmin, soporte, staff, root

**Cuenta raíz**:
La cuenta `morphos_core` fundadora, que ningún `morphos_core` puede
eliminar ni degradar, ni siquiera ella misma. Existe para que el
sistema no pueda quedarse sin superadministrador.
_Avoid_: cuenta maestra, admin principal

**Dashboard Global**:
La pantalla que mira todas las empresas a la vez, en lugar de una.
Exclusiva de `morphos_core`.
_Avoid_: panel de sistema, backoffice, panel de administración

**Supervisión contratada**:
Estado comercial de una empresa que compró acompañamiento del equipo
interno. Es un dato de facturación: **no concede ni niega ningún
permiso**.
_Avoid_: soporte premium, servicio gestionado

### Soporte

**Incidencia**:
Un caso de soporte abierto por cualquier usuario sobre su empresa, con
tipo, prioridad, responsable y un hilo hasta su cierre.
_Avoid_: ticket, caso, consulta, issue

**Alerta de cobro**:
Aviso dirigido al equipo interno sobre una membresía que vence pronto,
falló al cobrarse o ya venció. Siempre trata de dinero que las empresas
le deben a MORPHOS.
_Avoid_: aviso de impago, recordatorio de pago
