# Membresía, bloqueo y soporte

Glosario: [Comercial](../../contexts/comercial/CONTEXT.md).

## 1. Modelo de membresía

- **Una membresía por empresa.** Un `owner` con tres empresas paga tres
  membresías independientes, cada una con su vencimiento y su estado.
  El impago de una no afecta a las otras.
- **Titular** — el `owner` al que se le factura esa empresa. Es la
  única diferencia entre varios `owner` de la misma empresa, y puede
  transferirse entre ellos.
- **Ciclo mensual, prepago.** La membresía se paga por adelantado y
  cubre el mes siguiente de servicio. **No existe mora, ni cuentas por
  cobrar, ni incobrables**: nunca hay servicio prestado sin pagar.
- **Aviso de vencimiento**: 7 días naturales antes. Es el único aviso
  previo. La empresa entra en ese momento en la lista "próximas a
  vencer" del Dashboard Global.

El porqué de este modelo, y lo que se descartó, en
[ADR-0001](../adr/0001-membresia-prepago-con-bloqueo.md).

## 2. Estados de una empresa

| Estado | Qué significa | Cómo se llega |
|---|---|---|
| `activa` | Membresía vigente, opera con normalidad | Pago al día |
| `bloqueada` | Venció sin pago. Datos intactos, **recuperable** | Automático al vencimiento sin pago |
| `dada_de_baja` | Se fue por decisión propia | Acción explícita del titular o de `morphos_core` |

`bloqueada` es el embudo de cobro: son las empresas que se recuperan
con una llamada. `dada_de_baja` es abandono: **sale de los contadores
operativos** del Dashboard Global y solo alimenta la métrica de churn.
Mezclarlas convertiría el contador en un cementerio sin significado.

Una empresa bloqueada vuelve a `activa` en cuanto se registra el pago,
sin ningún paso manual y sin pérdida de datos.

## 3. Alcance del bloqueo

Al vencer sin pago:

| Rol | Acceso |
|---|---|
| `owner` | Sin acceso. Pantalla de renovación |
| `administrador` | Sin acceso. Pantalla de renovación |
| `trabajador` | Solo lectura de **su propio saldo y sus registros** |
| `vendedor` / `afiliado` | Solo lectura de **su propio saldo y sus registros** |

Nadie puede crear, confirmar, facturar ni cobrar. Ningún dato se
elimina ni se altera.

La excepción del saldo propio es deliberada: el saldo de un
`trabajador` es dinero que **su empresa le debe a él** por trabajo ya
realizado, y él no decidió el impago. La palanca de cobro apunta a
quien decide pagar; retener el registro laboral de un tercero no es
palanca, es riesgo.

### 3.1 La pantalla de bloqueo permite abrir incidencia

La pantalla de renovación incluye **"Tengo un problema con el pago"**,
que crea una incidencia de prioridad alta sin necesidad de entrar al
sistema. Sin esto, una empresa que pagó y sufrió un fallo de pasarela
no tendría ninguna vía para reclamar: el único canal de soporte estaría
detrás del bloqueo que quiere reclamar.

## 4. Soporte — incidencias

Entidad propia `incidencias`, con:

- `empresa_id`, `abierta_por`, `tipo`, `prioridad`, `estado`
- `responsable` — el `morphos_core` asignado
- Hilo de respuestas hasta el cierre, con su histórico

**Cualquier rol puede abrir una incidencia** sobre la empresa en la que
está — incluido el `trabajador` que discute su saldo, cuyo caso no
puede depender de que lo escale el `owner` con el que discrepa.

Las incidencias abiertas alimentan el bloque de alertas de soporte del
Dashboard Global.

## 5. Egresos de MORPHOS

Tabla propia, de alta **manual** por `morphos_core`:

| Campo | Notas |
|---|---|
| `fecha`, `concepto`, `importe` | |
| `categoria` | `infraestructura`, `nomina`, `proveedores`, `comisiones`, `otros` |
| `comprobante_id` | fk → `archivos`, opcional |
| `registrado_por` | usuario `morphos_core` que lo dio de alta |

Es deliberadamente mínimo: cubre el bloque de recaudo mensual sin
construir un módulo de contabilidad interna. Puede crecer más adelante
hacia importación desde una herramienta contable externa.

## 6. Recaudo — criterio de cálculo

El recaudo se contabiliza por **devengo**: el importe pertenece al
ciclo que cubre. Como el modelo es prepago (§1), devengo y caja
coinciden siempre en la práctica y no existen reversiones ni
incobrables que gestionar.

## 7. Supervisión contratada

Sigue existiendo como estado comercial de la empresa (contratada o no,
y desde cuándo) y se gestiona desde el Dashboard Global, pero **no
concede ni niega permisos**: `morphos_core` puede gestionarlo todo esté
o no contratada.

Consecuencia asumida: en el historial, `confirmed_by` dice quién
confirmó, pero deja de poder deducirse si fue un servicio contratado o
una intervención de soporte. Si esa distinción hiciera falta, se marca
en el propio registro (`ledger_entries.metadata`), no volviendo a
atarla a un flag de la empresa.
