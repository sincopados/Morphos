---
status: accepted
---

# Dos contextos delimitados con vocabularios disjuntos

MORPHOS mueve dos flujos de dinero distintos: el que va entre una
empresa cliente y **sus** clientes finales (obras, facturas, cobros), y
el que va entre MORPHOS y **las empresas** que le pagan (membresías).
Hasta ahora los dos usaban las mismas palabras — "ingresos", "cobros",
"gastos", "cliente" — y ya habían empezado a producir
contradicciones: el dashboard se declaraba "por empresa, nunca
consolidado" y al mismo tiempo mostraba un total agregado de todas.

Dividimos el dominio en dos contextos, **Operación** y **Comercial**,
cada uno con su glosario, y prohibimos que un término cruce: `cobro` es
siempre dinero de una obra, `recaudo` es siempre dinero de una
membresía, `cliente` es siempre el cliente final de una empresa y nunca
la empresa misma.

## Consecuencias

- **La documentación se parte.** `CONTEXT-MAP.md` en la raíz apunta a
  dos glosarios; las reglas de negocio y el esquema de datos salen de
  los glosarios y se mudan a `docs/spec/`. Los glosarios dejan de
  envejecer cada vez que cambia una tabla.
- **`empresa` y `usuario` son núcleo compartido** — las únicas dos
  entidades que ambos contextos nombran igual. Todo lo demás pertenece
  a uno solo.
- **Prohibido agregar Operación para producir Comercial.** Sumar los
  cobros de todas las empresas no da una métrica de MORPHOS; da un
  número sin significado. Si alguna vez hace falta esa cifra, se
  modela explícitamente como métrica de producto, no como dinero.
- Los nombres de tabla y de API deberán respetar la frontera desde el
  principio. Renombrar después es mucho más caro que elegir bien ahora.

## Alternativas descartadas

- **Un solo contexto con términos prefijados** (`cobro_obra` vs
  `cobro_membresia`). Mantiene un fichero único, a costa de un
  vocabulario ruidoso y de que la frontera dependa de que nadie olvide
  el prefijo.
- **No distinguir** y confiar en que el lector deduzca el significado
  por la sección. Es exactamente lo que ya estaba fallando.
