# MORPHOS

Motor de saldo y confirmación para gestión de personal, ventas y afiliados. Ver [CONTEXT.md](./CONTEXT.md) para el glosario del dominio y [docs/adr/](./docs/adr/) para las decisiones de arquitectura.

Construido con [Nuxt 4](https://nuxt.com) + [Nuxt UI](https://ui.nuxt.com) (Tailwind CSS v4), `@nuxtjs/i18n` (español/inglés) y `@nuxtjs/supabase`.

## Setup

```bash
pnpm install
```

Copia `.env.example` a `.env` y completa las credenciales de Supabase.

## Development Server

```bash
pnpm dev
```

Servidor en `http://localhost:3000`.

## Production

```bash
pnpm build
pnpm preview
```

Ver la [documentación de deployment de Nuxt](https://nuxt.com/docs/getting-started/deployment).

## Renovate integration

Install [Renovate GitHub app](https://github.com/apps/renovate/installations/select_target) on your repository and you are good to go.
