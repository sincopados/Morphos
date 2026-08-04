# MORPHOS — Roadmap de Implementación: Fase 0.5 Workforce
### Por hitos y dependencias reales, no por calendario forzado
### Cliente piloto: SmartPainting (Nueva York)

---

## Cómo leer este roadmap

No hay fechas fijas ni "semana 1, semana 2". Cada hito tiene lo que
realmente determina cuánto tarda: qué depende de qué, qué riesgo tiene,
y un rango de esfuerzo *estimado* (no un plazo prometido) para que
puedas planear con Claude Code sin comprometerte con un cliente a una
fecha que la realidad del desarrollo no va a respetar. Construir bien
el Hito 2 (el motor) es lo que evita reconstruir todo en el Hito 4.

---

## Hito 0 — Ya completado (no repetir)

- Esquema de datos completo (`morphos_fase_0_5_schema_v1.sql`)
- Especificación funcional (`MORPHOS_Workforce_Ledger_Spec_v1.md`)
- Wireframes de onboarding y flujo diario, validados con prototipo
  interactivo (`morphos_prototipo_v2.html`)
- Identidad visual definida (Cian Morphos, Blanco Sistema, Negro
  Profundo; símbolo M; tipografía a definir en implementación real)
- Reconciliación con la Architecture Bible original (MASTER = Business
  Brain, DIG = Business Domains — sin tocar ahora, es Fase 1+)

**Riesgo si se salta este hito:** ninguno — ya está resuelto. Se
menciona para que quien retome esto en Claude Code no lo re-diseñe
por accidente.

---

## Hito 1 — Infraestructura base

**Objetivo:** que exista un entorno real donde correr código, no solo
diagramas.

- Repositorio del proyecto (estructura backend/frontend/db)
- Base de datos desplegada (Supabase u otro Postgres gestionado) con
  `morphos_fase_0_5_schema_v1.sql` ejecutado
- Autenticación real: Google OAuth + correo/contraseña (según el
  onboarding ya diseñado)
- Entorno de staging separado del de producción — para no probar
  cambios directamente donde SmartPainting ya esté operando

**Depende de:** decisión técnica pendiente — ¿Supabase o infraestructura
propia? (recomendado: Supabase para esta etapa, ver Spec v1 §... )

**Riesgo:** si se decide infraestructura propia "porque se ve más
profesional", este hito se alarga sin necesidad — es exactamente el
tipo de sobre-ingeniería que ya evitamos con el motor de reglas.

**Esfuerzo estimado (no fecha límite):** días, no semanas, si se usa
Supabase; considerablemente más si se construye infraestructura propia
desde cero.

---

## Hito 2 — El motor de Ledger (backend)

**Objetivo:** implementar la lógica real detrás del esquema — esto es
el corazón de todo MORPHOS Workforce, no una feature más.

- API para crear `ledger_entries` (check-in, venta, extra/deducción)
- API de confirmación/rechazo, con el trigger de "nunca autoconfirmar"
  ya reforzado a nivel de base de datos (no solo en el backend)
- Lógica de `compliance_alerts`: comparar `amount`/`hours_reported`
  contra `compliance_rules` y generar la alerta informativa (nunca
  bloqueante)
- Lógica de `modification_requests`: ventana de 72h, motivo obligatorio
  después de esa ventana
- Vista de saldo en tiempo real (`v_user_balance` ya definida en el SQL)

**Depende de:** Hito 1 (necesita base de datos y auth funcionando)

**Riesgo real a vigilar:** que alguien "simplifique" el motor
confundiendo `ledger_entries` con una tabla de asistencia tradicional.
Si se pierde la generalización (trabajador/vendedor/afiliado en una
sola tabla), se termina reconstruyendo esto dos veces cuando llegue el
primer cliente que necesite afiliados.

**Esfuerzo estimado:** el hito más largo de todos — es donde vive la
complejidad real del sistema, no en las pantallas.

---

## Hito 3 — Onboarding real (conectado al backend)

**Objetivo:** que el flujo que ya se validó en el prototipo (7
pantallas) funcione contra datos reales, no simulados.

- Registro con Google OAuth funcional (no simulado)
- Las bifurcaciones reales: equipo de 0 personas bloquea de verdad;
  "no estoy seguro" dispara una notificación real al equipo de MORPHOS
  para ofrecer supervisión a distancia, no solo un mensaje en pantalla
- Generación real del `referral_code` único por empresa
- Creación del Company DNA inicial en la base de datos (no solo en la
  UI, como en el prototipo)

**Depende de:** Hito 2 (necesita que `companies`/`users` ya se puedan
crear correctamente vía API)

**Esfuerzo estimado:** moderado — la lógica ya está resuelta en el
prototipo, esto es principalmente conectarla a datos reales.

---

## Hito 4 — Apps de uso diario (frontend de producción)

**Objetivo:** llevar el prototipo HTML de demostración a la
plataforma real que va a usar SmartPainting en campo.

- Decisión pendiente: ¿React Native (recomendado originalmente) o PWA
  instalable? Esto afecta directamente cómo se implementa el QR diario
  y la geolocalización — vale la pena resolverlo antes de empezar este
  hito, no durante.
- Check-in con QR real (que cambia diariamente) + captura de GPS
- Registro de venta/servicio para vendedores/afiliados
- Panel del administrador (bandeja de pendientes, confirmar/rechazar
  con motivo obligatorio) — ya validado en el prototipo, se traslada
  con la lógica real detrás

**Depende de:** Hito 2 y 3 (necesita el motor y el onboarding
funcionando de verdad)

**Riesgo:** construir esto antes de que el motor esté sólido significa
reconstruir pantallas cuando cambie la lógica de negocio por debajo.

**Esfuerzo estimado:** considerable, comparable al Hito 2 — es la
parte que el usuario final toca todos los días, así que merece el
mismo cuidado que el backend, no menos.

---

## Hito 5 — Piloto controlado con SmartPainting

**Objetivo:** validar con datos reales, no con datos de demostración.

- Cargar la empresa real SmartPainting con su equipo real
- Definir un período de prueba acotado (ej. una quincena completa) con
  seguimiento cercano — no lanzar y desentenderse
- Recolectar feedback de fricción real: ¿el QR funciona bien en campo?
  ¿el dueño confirma a tiempo? ¿las alertas de compliance se entienden?
- Comparar la nómina sugerida por MORPHOS contra la nómina real que el
  dueño terminó pagando — esta comparación es, literalmente, el primer
  dato real de "evaluar" del ciclo aprender-mutar-evaluar-mejorar

**Depende de:** Hitos 1-4 completos y estables

**Esta es la fase que genera el primer dato real para MASTER/Company
DNA** — antes de esto, todo lo que "aprende" el sistema es teórico.

---

## Hito 6 — Ajustes post-piloto

**Objetivo:** cerrar la brecha entre lo que se diseñó en el papel y lo
que realmente pasó con un cliente de verdad — siempre hay brecha, y
fingir que no la hay es el error más común en este punto.

- Ajustar valores sugeridos por industria según lo observado
- Revisar si las alertas de compliance se mostraron cuando debían
- Decidir, con datos reales en mano, si se avanza a un segundo cliente
  piloto o se refina más antes de escalar

**Depende de:** Hito 5 completo, con al menos un período de pago
completo corrido de principio a fin.

---

## Lo que este roadmap NO incluye (a propósito)

- MASTER, los DIG, MORPHOS LAB, Founder Mode — eso es Fase 1 en
  adelante, según ya reconciliamos. Construirlo ahora sería exactamente
  el tipo de dependencia-de-infraestructura-sin-uso que evitamos con
  Neo4j/pgvector.
- Un segundo cliente o una segunda industria — hasta que el Hito 6 no
  esté cerrado con datos reales de SmartPainting, no hay base para
  decidir bien qué generalizar para el siguiente cliente.
