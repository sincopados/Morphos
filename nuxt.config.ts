import { createRequire } from 'node:module'
import { dirname, join } from 'node:path'

// @supabase/* importa tslib; sin este alias el bundler resuelve la build
// CJS y el prerender falla con
// "Cannot destructure property '__extends' of '__toESM(...).default'".
// Se resuelve a ruta absoluta para que el alias no se reaplique en bucle.
const tslibEsm = createRequire(import.meta.url).resolve('tslib/tslib.es6.mjs')

// @nuxtjs/supabase importa `h3` sin fijar version. En el bundle SSR de Nuxt eso
// resuelve a h3 v2, pero los eventos que recibe vienen de Nitro 2.13, que sigue
// en h3 v1: `getRequestHeader` de v2 espera `event.req.headers.get` y revienta
// con "event.req.headers.get is not a function" en cada peticion SSR, dejando
// al servidor sin poder leer la sesion. Se ancla a la v1 que usa Nitro.
// h3 esta en devDependencies fijado a la misma version que Nitro (1.15.11).
// Se apunta al ESM: el CJS no expone los named exports que espera el bundle.
// El `exports` de h3 no publica subrutas, asi que se llega por ruta de archivo
// a partir de la que si resuelve.
const h3V1 = join(
  dirname(createRequire(import.meta.url).resolve('h3')),
  'index.mjs'
)

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: [
    '@nuxt/eslint',
    '@nuxt/ui',
    '@nuxtjs/i18n',
    '@nuxtjs/supabase'
  ],

  devtools: {
    enabled: true
  },

  css: ['~/assets/css/main.css'],

  runtimeConfig: {
    public: {
      // El boton de Google solo se muestra cuando el proveedor esta habilitado
      // en el dashboard de Supabase; si no, `signInWithOAuth` manda al usuario
      // a una pagina de error del propio Supabase.
      googleAuthEnabled: false
    }
  },

  alias: {
    tslib: tslibEsm
  },

  routeRules: {
    '/': { prerender: true }
  },

  compatibilityDate: '2026-06-30',

  nitro: {
    alias: {
      tslib: tslibEsm
    }
  },

  vite: {
    plugins: [
      {
        // El alias de h3 tiene que ser quirurgico: aplicarlo a todo el bundle
        // rompe a Nuxt, que si usa la API de h3 v2 (`H3Error` y compania).
        // Solo se redirige lo que importa @nuxtjs/supabase.
        name: 'morphos:supabase-h3-v1',
        enforce: 'pre',
        resolveId(source: string, importer?: string) {
          if (source === 'h3' && importer?.includes('@nuxtjs/supabase')) {
            return h3V1
          }
          return null
        }
      }
    ]
  },

  eslint: {
    config: {
      stylistic: {
        commaDangle: 'never',
        braceStyle: '1tbs'
      }
    }
  },

  i18n: {
    // Necesario para que los enlaces SEO (canonical/alternate) salgan con
    // dominio absoluto. En produccion se define via NUXT_PUBLIC_SITE_URL.
    baseUrl: process.env.NUXT_PUBLIC_SITE_URL || 'http://localhost:3000',
    defaultLocale: 'es',
    locales: [
      { code: 'es', language: 'es-ES', name: 'Español', file: 'es.json' },
      { code: 'en', language: 'en-US', name: 'English', file: 'en.json' }
    ],
    strategy: 'prefix_except_default'
  },

  supabase: {
    redirectOptions: {
      login: '/login',
      callback: '/confirm',
      // El guard compara `to.path` exacto contra estos patrones, y `login` y
      // `callback` ya quedan excluidos por su cuenta. Como i18n usa
      // `prefix_except_default`, cada ruta publica necesita tambien su
      // variante con prefijo: un patron amplio como `/en/*` dejaria sin
      // proteger toda la app en ingles.
      exclude: [
        '/',
        '/registro',
        '/en',
        '/en/login',
        '/en/registro',
        '/en/confirm'
      ]
    }
  }
})
