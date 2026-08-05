# Empresas, obras y usuarios

Glosario: [Operación](../../contexts/operacion/CONTEXT.md).

## 1. Cardinalidad (regla base del modelo)

- **Una empresa tiene muchas obras.** Una obra pertenece siempre a una
  sola empresa; no se comparten obras entre empresas.
- **Un usuario pertenece a una o varias empresas.** Ninguna cuenta está
  atada a una única empresa: la misma persona puede trabajar para
  varias y cambia entre ellas con un selector. El rol se define **por
  empresa**, no por persona — alguien puede ser `owner` de la suya y
  `trabajador` en otra, y cada pertenencia lleva su propio rol, su
  propio saldo y su propia tarifa.
- **Un dueño puede tener varias empresas.** Cada una mantiene sus
  datos, usuarios y contabilidad completamente separados, y **cada una
  paga su propia membresía** (ver [30-comercial.md](./30-comercial.md)).
- **Una empresa puede tener uno o más dueños.** Se admiten varios
  `owner` sobre la misma empresa (socios), todos con el mismo alcance
  total. Uno queda marcado como **titular** de la membresía — el que
  paga —, y esa es la única diferencia entre ellos.
- En resumen: `usuario` ↔ `empresa` es **muchos a muchos** y el rol es
  un atributo de esa relación; `empresa` → `obra` es **uno a muchos**.

## 2. Definiciones estructurales

- **Empresa** — unidad raíz. Los datos nunca cruzan de una empresa a
  otra, ni siquiera entre empresas del mismo dueño.
- **Obra** — unidad operativa dentro de una empresa. Es el nivel al que
  se asignan administradores, tareas, cobros y gastos, y el eje de
  todos los desgloses del dashboard de empresa.
- Estados de una obra: `activa`, `cerrada`, `archivada`. Solo las
  activas aparecen en los desgloses operativos.
- Los movimientos que no pertenecen a ninguna obra concreta se imputan
  a la obra virtual **"General / Empresa"**, que existe siempre y no se
  puede borrar.

## 3. Roles (`user_role`)

| Rol | Quién es | Alcance |
|---|---|---|
| `owner` | Dueño del negocio, cuenta maestra. Puede haber varios por empresa, y una persona puede serlo de varias empresas | Toda la empresa (o empresas) de la que es dueño, con todas sus obras |
| `administrador` | Administrador que el dueño designa | Las obras que tiene asignadas |
| `trabajador` | Persona con horario fijo (asistencia por bloques) | Hace check-in de entrada y salida, genera sus partes de trabajo, solo ve su propio saldo |
| `vendedor` | Genera ventas para su empresa | Solo sus ventas y su propio saldo |
| `afiliado` | Genera referidos y comisiones, sin horario | Solo sus referidos y su propio saldo |
| `morphos_core` | Equipo interno de MORPHOS | Superadministrador de todo el sistema y todas sus empresas |

### 3.1 `morphos_core` es excluyente

`morphos_core` es un rol **global**: no cuelga de ninguna empresa y
aplica a todo el sistema. Por eso es **incompatible con cualquier
pertenencia**: quien tiene `morphos_core` no puede ser `owner`,
`administrador`, `trabajador`, `vendedor` ni `afiliado` de ninguna
empresa. Asignarle el rol a un usuario con pertenencias activas se
rechaza, y viceversa.

El motivo y lo que se sacrifica están en
[ADR-0002](../adr/0002-morphos-core-rol-global-excluyente.md).

### 3.2 Cuenta raíz

Existe una cuenta `morphos_core` marcada como **raíz**. Ningún
`morphos_core` puede eliminarla ni retirarle el rol — ni siquiera ella
misma. Garantiza que el sistema nunca se quede sin superadministrador,
situación de la que no habría forma de salir desde dentro del producto
porque el rol es global y excluyente.

## 4. Perfiles (`profile_type`)

- **`con_horario`** — usa check-in de bloques de tiempo (día completo =
  8 h, medio día = 4 h, más una casilla opcional de extra/deducción).
  Aplica a `trabajador`.
- **`sin_horario`** — no hace check-in de tiempo; genera un registro
  cada vez que ocurre un evento (una venta, un referido, un servicio
  prestado). Aplica a `vendedor` y `afiliado`.

## 5. Pertenencia a empresa y asignación a obras

- Cualquier usuario puede pertenecer a una o varias empresas, con un
  rol distinto en cada una. `morphos_core` es la excepción (§3.1).
- Nada se comparte entre las empresas de una misma persona: el saldo,
  la tarifa, el historial y los permisos son de la pertenencia, no del
  usuario. Cambiar de empresa en el selector cambia todo lo que ve.
- El `owner` asigna a cada `administrador` una o varias obras de esa
  empresa; fuera de ellas no ve datos ni puede operar.
- `trabajador`, `vendedor` y `afiliado` ven únicamente sus propios
  registros y su propio saldo dentro de esa empresa, nunca los totales
  de la empresa ni de la obra.
- Toda acción sobre un registro económico queda auditada con usuario,
  fecha y obra afectada.

## 6. Autenticación

Dos caminos, mismo modelo de datos al final: **Google OAuth** o
**correo/contraseña**.

## 7. Modificación de registros después de confirmados

- **Ventana de 72 horas**: el `owner` puede modificar libremente.
- Después de 72 horas: requiere solicitud formal con motivo, registrada
  en `modification_requests`, visible para el usuario afectado si hay
  disputa.
- `morphos_core` puede modificar sin restricción de ventana, siempre
  auditado igual que el dueño.
