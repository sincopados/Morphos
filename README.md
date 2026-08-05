# MORPHOS

Sistema Operativo Empresarial Adaptativo. Aplicación Nuxt 4 construida sobre
el modelo documentado en [CONTEXT-MAP.md](./CONTEXT-MAP.md).

## Los dos contextos, también en el código

La frontera de [ADR-0003](./docs/adr/0003-dos-contextos-operacion-y-comercial.md)
se ve en el árbol de rutas:

| Ruta | Contexto | Quién entra |
|---|---|---|
| `/e/:slug/*` | **Operación** — obras, gente, dinero con clientes finales | Quien pertenece a esa empresa |
| `/global/*` | **Comercial** — membresías, bloqueo, soporte, egresos | Solo `morphos_core` |

`cobro` nunca significa dinero de una membresía, y `recaudo` nunca significa
dinero de una obra. Los glosarios están en [contexts/](./contexts/).

## Puesta en marcha

```bash
pnpm install
cp .env.example .env      # rellena las tres claves
pnpm dev
```

`NUXT_PUBLIC_SUPABASE_URL` y `NUXT_PUBLIC_SUPABASE_KEY` son obligatorias.
`SUPABASE_SERVICE_KEY` solo hace falta para **crear usuarios** desde el
Dashboard Global: es la única operación que necesita privilegios de
administración, vive en [server/api/global/usuarios.post.ts](./server/api/global/usuarios.post.ts)
y nunca sale al navegador. Sin ella el alta responde 501 y el resto de la
aplicación funciona con normalidad.

### Base de datos

Aplica las migraciones en orden contra tu proyecto de Supabase:

```bash
supabase db push          # o ejecuta supabase/migrations/*.sql a mano
```

- `0001_init.sql` — esquema, invariantes y RLS.
- `0002_bloqueo.sql` — bloqueo por vencimiento y registro de pagos.
- `seed.sql` — datos de ejemplo. Crea antes las tres cuentas que indica su
  cabecera; resuelve los usuarios por email, así que no hay UUID que editar.

Programa `aplicar_vencimientos()` a diario con `pg_cron` para que el bloqueo
por impago ocurra solo:

```sql
select cron.schedule('vencimientos', '0 3 * * *', 'select aplicar_vencimientos()');
```

## Dónde vive cada regla del dominio

Las decisiones no se quedaron en la documentación — están donde se pueden
hacer cumplir:

| Regla | Dónde |
|---|---|
| `morphos_core` es excluyente con toda pertenencia | Trigger `assert_morphos_core_excluyente` |
| La cuenta raíz no se elimina ni se degrada | Trigger `assert_raiz_intocable` |
| Con la empresa bloqueada nadie escribe | `empresa_escribible()` en cada policy |
| El trabajador conserva la lectura de su saldo | Policy `bloques_select` + [middleware/empresa.ts](./app/middleware/empresa.ts) |
| Reclamar un pago sin poder entrar | [pages/e/[slug]/bloqueada.vue](./app/pages/e/%5Bslug%5D/bloqueada.vue) |
| Prepago: pagar extiende el ciclo y desbloquea | `registrar_pago_membresia()` |
| El Dashboard Global es invisible para el resto | [middleware/morphos-core.ts](./app/middleware/morphos-core.ts) |
| La mano de obra se deriva del check-in | `horasDeBloque()`, sin alta manual en ninguna pantalla |

## Stack

- **Nuxt 4** con el directorio `app/`.
- **@nuxt/ui 4** sobre Tailwind 4, con la paleta de marca en
  [main.css](./app/assets/css/main.css).
- **@nuxtjs/i18n** en español e inglés, sin prefijo de idioma en la URL: las
  rutas de empresa (`/e/:slug`) no cambian al cambiar de idioma.
- **@nuxtjs/supabase** para auth (Google OAuth y correo/contraseña) y datos.
- **@nuxt/icon** con las colecciones empaquetadas: sin llamadas a la API de
  Iconify en producción.
- **@formkit/auto-animate** en listados, tablas y formularios desplegables.
- **@nuxt/eslint** con reglas de estilo activadas.

## Comandos

```bash
pnpm dev         # desarrollo
pnpm build       # build de producción
pnpm lint        # eslint
pnpm typecheck   # vue-tsc
```
