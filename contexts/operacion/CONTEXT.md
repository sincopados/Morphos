# Operación

Cómo trabaja por dentro una empresa cliente de MORPHOS: sus obras, su
gente y el dinero que se mueve entre la empresa y sus clientes finales.
Este contexto no sabe nada de membresías ni de la contabilidad de
MORPHOS — eso vive en [Comercial](../comercial/CONTEXT.md).

## Language

### Estructura

**Empresa**:
Unidad raíz del contexto. Agrupa a sus usuarios, sus obras y todos sus
movimientos económicos, que nunca cruzan a otra empresa.
_Avoid_: organización, cuenta, tenant

**Obra**:
Unidad operativa dentro de una empresa — un proyecto, sitio o centro de
coste. Es el nivel al que se imputan tareas, cobros y gastos.
_Avoid_: proyecto, job, trabajo

**General / Empresa**:
Obra virtual que existe siempre en toda empresa y no se puede borrar.
Recoge los movimientos que no pertenecen a ninguna obra concreta.
_Avoid_: obra por defecto, sin obra, overhead

**Cliente**:
La persona u organización a la que una empresa le factura una obra. Es
el cliente **de la empresa**, nunca el cliente de MORPHOS.
_Avoid_: comprador, contacto

### Personas

**Pertenencia**:
El vínculo entre un usuario y una empresa. Es la pertenencia — no el
usuario — la que tiene rol, tarifa y saldo, y una misma persona puede
tener varias con valores distintos.
_Avoid_: membresía, afiliación, membership

**Owner**:
Dueño de una empresa, con alcance total sobre ella y todas sus obras.
Una empresa puede tener varios; una persona puede serlo de varias
empresas.
_Avoid_: dueño, admin, propietario

**Administrador**:
Usuario al que un `owner` asigna obras concretas. Gestiona todo dentro
de esas obras y no ve nada fuera de ellas.
_Avoid_: manager, supervisor, encargado

**Trabajador**:
Persona con perfil `con_horario` que registra su tiempo mediante
check-in. Solo ve sus propios registros y su propio saldo.
_Avoid_: empleado, operario, staff

**Vendedor**:
Persona con perfil `sin_horario` que genera ventas para la empresa y
cobra por ellas.
_Avoid_: comercial, agente

**Afiliado**:
Persona con perfil `sin_horario` que genera referidos y cobra comisión,
sin vínculo de horario con la empresa.
_Avoid_: partner, referidor

**Perfil**:
Determina cómo una persona genera registros: `con_horario` marca
bloques de tiempo, `sin_horario` genera un registro por cada evento.
_Avoid_: modalidad, tipo de contrato

**Saldo**:
Lo que una empresa le debe a una persona por su trabajo ya registrado.
Es de la pertenencia: la misma persona tiene un saldo distinto en cada
empresa.
_Avoid_: balance, nómina, deuda

### Tiempo y trabajo

**Check-in**:
El acto por el que un `trabajador` abre un bloque de tiempo y elige a
qué obra lo imputa. Es la **única** forma de que entren horas al
sistema: no existe alta manual.
_Avoid_: fichaje, registro de horas, timesheet

**Bloque**:
La unidad de tiempo que produce un check-in — día completo, medio día,
más una extra o deducción opcional.
_Avoid_: jornada, turno, entrada

**Tarifa**:
El precio por hora de una pertenencia. Está versionada: cambiarla hoy
no reescribe el coste de las obras pasadas.
_Avoid_: sueldo, precio hora, rate

**Mano de obra**:
El coste en personas de una obra, derivado siempre de los bloques
confirmados y su tarifa vigente. Nunca se teclea.
_Avoid_: labor, coste de personal

### Dinero

**Cobro**:
Dinero efectivamente recibido de un cliente final, con el pago
confirmado. Una venta registrada no es un cobro hasta que el dinero
entra.
_Avoid_: ingreso, pago, recaudo

**Gasto**:
Coste directo imputado a una obra — materiales, equipo, subcontratas.
Solo suma cuando está confirmado.
_Avoid_: egreso, coste, expense

**Factura**:
La petición de pago que una empresa emite a un cliente final. Puede
agrupar varias obras del mismo cliente.
_Avoid_: recibo, nota, invoice

**Margen**:
Cobros de una obra menos sus gastos. Admite valores negativos: una obra
puede estar en pérdida.
_Avoid_: beneficio, rentabilidad, profit

### Control

**Confirmado**:
El estado que hace que un registro exista a efectos de dinero. Nada sin
confirmar suma a ningún total.
_Avoid_: aprobado, validado, cerrado

**Ventana de 72 horas**:
El plazo durante el que un `owner` puede modificar libremente un
registro confirmado. Pasado ese plazo hace falta una solicitud de
modificación.
_Avoid_: período de gracia, plazo de edición

**Solicitud de modificación**:
La petición formal y motivada para cambiar un registro confirmado fuera
de la ventana de 72 horas. Queda visible para el usuario afectado.
_Avoid_: enmienda, corrección, ajuste
