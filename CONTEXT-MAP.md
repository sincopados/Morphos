# Context Map — MORPHOS

MORPHOS tiene dos contextos delimitados. Ambos hablan de dinero, de
empresas y de personas, pero **con vocabularios distintos que no se
cruzan**. Confundirlos es el error más caro que se puede cometer en
este proyecto: "cobro" y "recaudo" no son sinónimos, y ninguno de los
dos puede usarse para nombrar lo del otro lado.

## Contextos

- [Operación](./contexts/operacion/CONTEXT.md) — cómo trabaja una
  empresa cliente: sus obras, su gente, y el dinero que se mueve entre
  **la empresa y sus clientes finales**.
- [Comercial](./contexts/comercial/CONTEXT.md) — cómo funciona MORPHOS
  como negocio: membresías, bloqueos, soporte, y el dinero que se mueve
  entre **MORPHOS y las empresas que le pagan**.

## Relación entre contextos

- **Núcleo compartido**: `empresa` y `usuario` son las únicas entidades
  que ambos contextos nombran igual. Todo lo demás es propio de uno.
- **Comercial → Operación**: el estado de la membresía decide si la
  empresa puede operar. Una empresa `bloqueada` conserva todos sus
  datos de Operación intactos, pero deja de admitir escritura.
- **Operación → Comercial**: Operación no sabe nada de membresías ni de
  recaudo. Nunca consulta hacia arriba.
- **Prohibido**: agregar cifras de Operación entre empresas para
  producir una métrica de Comercial. El dinero de las obras nunca es
  dinero de MORPHOS.

## Falsos amigos

| En Operación significa | Palabra | En Comercial significa |
|---|---|---|
| Dinero recibido de un cliente final por una obra | **cobro** | *(no se usa — di `recaudo`)* |
| *(no se usa — di `gasto`)* | **egreso** | Coste de MORPHOS como negocio |
| El cliente final al que una empresa le factura una obra | **cliente** | *(no se usa — di `empresa`)* |
| Estado operativo de una obra en curso | **activa** | Empresa con membresía vigente |

## Especificación y decisiones

Los glosarios definen **palabras**. Las reglas de negocio, los bloques
de cada pantalla y el esquema de datos viven en [docs/spec/](./docs/spec/);
las decisiones estructurales y su porqué, en [docs/adr/](./docs/adr/).
