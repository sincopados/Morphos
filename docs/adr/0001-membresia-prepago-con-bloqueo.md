---
status: accepted
---

# Membresía prepago mensual con bloqueo, sin mora

Cada empresa paga por adelantado un ciclo mensual; si al vencimiento no
hay pago, la empresa se bloquea de inmediato y vuelve al instante en
cuanto paga. Elegimos el modelo de suscripción de consumo (Netflix) en
lugar de facturar a mes vencido porque elimina de raíz toda una clase
de problemas: no hay cuentas por cobrar, ni días de mora, ni
incobrables que provisionar, ni ingresos históricos que reescribir
cuando alguien nunca paga.

## Consecuencias

- **Asimetría deliberada con las empresas.** El dashboard de empresa
  usa criterio de **caja** — un cobro solo suma cuando el dinero entra
  — mientras que MORPHOS se contabiliza a sí misma por **devengo**. No
  es una incoherencia: con prepago, devengo y caja coinciden siempre,
  porque nunca existe servicio prestado y no cobrado. Un lector que vea
  las dos reglas juntas debe saber que la diferencia es de modelo de
  negocio, no de descuido.
- **El bloque de recaudo pierde el estado "pendiente".** No existen
  membresías facturadas y no cobradas, así que el Dashboard Global solo
  muestra *pagas* y *próximas a vencer*.
- **Un fallo de pasarela bloquea a un cliente que sí quería pagar.** Se
  mitiga con la incidencia de prioridad alta que se puede abrir desde
  la propia pantalla de bloqueo, sin necesidad de entrar.
- **El `owner` pierde acceso a su propia contabilidad** mientras esté
  bloqueado. Es la palanca de cobro y es intencionado; los datos se
  conservan íntegros.

## Alternativas descartadas

- **Postpago con mora e incobrables** — refleja mejor un negocio de
  servicios, pero obliga a modelar umbrales de mora, provisiones,
  egresos por incobrable y meses cerrados que hay que decidir si se
  reescriben o no. Complejidad desproporcionada para vender
  suscripciones de software.
- **Solo lectura en vez de bloqueo** — más suave con el cliente, pero
  deja al `owner` operando sin pagar y elimina casi toda la presión de
  cobro.
- **Período de gracia tras el vencimiento** — reintroduce un estado
  intermedio y, con él, la ambigüedad que este modelo existe para
  evitar.
