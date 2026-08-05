# Dashboard Global de MORPHOS

Glosario: [Comercial](../../contexts/comercial/CONTEXT.md).

Dashboard **independiente** del de empresa, porque no mira una empresa
sino todas: es la vista de infraestructura y estructura general del
sistema.

## Acceso exclusivo

Únicamente el rol `morphos_core` tiene el privilegio de entrar. Dentro
puede **visualizar y modificar toda la información del sistema, sin
excepciones**: empresas, usuarios, equipos, obras, asignaciones de
administrador, membresías, incidencias y confirmación de movimientos
del ledger.

Ningún `owner` ni `administrador` puede acceder a esta ruta, ni verla
en el menú, ni alcanzarla por URL directa. `morphos_core` no pertenece
a ninguna empresa (rol excluyente, ver
[10-empresas-y-usuarios.md](./10-empresas-y-usuarios.md) §3.1).

Toda acción realizada desde aquí queda auditada con usuario, fecha,
empresa afectada y valor anterior/nuevo.

## 1. Bloques

### 1.1 Empresas por estado

Contadores de **activas** y **bloqueadas**, con la variación respecto
al período anterior. Al pinchar cada contador se abre el listado
filtrado.

Las empresas **dadas de baja** no entran en estos contadores: se
muestran aparte como métrica de abandono, con su histórico. Ver
[30-comercial.md](./30-comercial.md) §2.

### 1.2 Recaudo de membresías

Dos estados, con importe total y número de empresas en cada uno:

- **Pagas** — membresías cobradas y confirmadas en el período.
- **Próximas a vencer** — las que vencen dentro de los 7 días
  naturales de la ventana de aviso, ordenadas por fecha más cercana.

No existe un estado "pendientes con mora": el modelo es prepago y no
genera cuentas por cobrar.

### 1.3 Recaudo mensual

Estado económico de MORPHOS como negocio en el mes en curso:

- **Ingresos** — recaudo de membresías del mes.
- **Egresos** — infraestructura, nómina interna, proveedores,
  comisiones, otros (alta manual, ver
  [30-comercial.md](./30-comercial.md) §5).
- **Neto del mes** y comparativa contra el mes anterior.

Es la contabilidad de MORPHOS, **completamente separada** de la
contabilidad de cada empresa. Ninguna cifra de este bloque sale de
agregar obras, cobros ni gastos de las empresas.

### 1.4 Alertas de soporte

Incidencias abiertas, con empresa, tipo, prioridad, antigüedad y
responsable asignado. Se pueden atender, reasignar y cerrar desde el
propio dashboard.

Se marcan con prioridad alta las incidencias abiertas desde la pantalla
de bloqueo, que son reclamaciones de pago.

### 1.5 Alertas de cobro

Membresías que vencen en los próximos 7 días, pagos fallidos y empresas
ya bloqueadas. Siempre se refiere a lo que **las empresas le deben a
MORPHOS** — nunca a la morosidad de los clientes finales de una
empresa, que es un asunto de Operación.

Acciones disponibles: disparar el recordatorio al titular, registrar un
pago manual, o dar de baja la empresa.

### 1.6 Resumen del sistema

Personas activas, obras activas, movimientos pendientes de confirmar y
cuántas empresas tienen supervisión contratada.

## 2. Subpágina — Gestión total de usuarios

CRUD completo sobre **todos los usuarios del sistema**, con todos los
privilegios y sin límite de empresa:

- Crear, ver, editar y eliminar cualquier usuario, de cualquier
  empresa.
- Gestionar sus pertenencias: añadir o quitar empresas, cambiar el rol
  en cada una, ajustar tarifa y saldo de esa pertenencia — recordando
  que rol, tarifa y saldo son atributos de la pertenencia, no de la
  persona.
- Asignar y revocar el rol `morphos_core`, sujeto a las reglas de §2.1.
- Acciones de cuenta: forzar restablecimiento de contraseña,
  desvincular Google OAuth, suspender y reactivar la cuenta.
- Búsqueda y filtrado por empresa, rol, perfil y estado; ver el
  historial de auditoría de cada usuario.
- El borrado es **lógico** por defecto (conserva historial y
  auditoría); el borrado físico solo procede si el usuario no tiene
  registros económicos asociados.

### 2.1 Invariantes que el CRUD no puede romper

- **La cuenta raíz es intocable**: no se puede eliminar, ni
  degradar, ni suspender, ni siquiera por sí misma.
- **`morphos_core` es excluyente**: asignar el rol a un usuario con
  pertenencias activas se rechaza, y añadir una pertenencia a un
  `morphos_core` también.

## 3. Subpágina — Gestión general de las empresas

- **Listado** — cada empresa con su estado (`activa` / `bloqueada` /
  `dada_de_baja`), jurisdicción, tamaño de equipo, obras activas,
  ingresos de la semana, movimientos pendientes, fecha de vencimiento
  de la membresía y si le faltan reglas de compliance cargadas.
- **Ficha de empresa** — alta, edición y baja; datos fiscales, zona
  horaria, plan y membresía, supervisión contratada, reglas de
  compliance, usuarios y sus roles, obras y configuración.
- **Entrar a gestionar una empresa** — selecciona esa empresa como
  activa y reutiliza las pantallas normales. No hay una versión "de
  soporte" de cada pantalla: es la misma, con más alcance. Incluye
  dashboard, obras, facturación y cobros.
- **Acciones sobre la empresa** — registrar un pago manual, dar de
  baja, reactivar, cambiar de plan, aplicar descuentos o prórrogas de
  membresía, y transferir la titularidad entre los `owner`.
