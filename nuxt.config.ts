// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({

  modules: [
    '@nuxt/eslint',
    '@nuxt/icon',
    '@nuxt/ui',
    '@nuxtjs/i18n',
    '@nuxtjs/supabase',
    '@formkit/auto-animate/nuxt',
  ],
  devtools: { enabled: true },

  css: ['~/assets/css/main.css'],

  future: { compatibilityVersion: 4 },
  compatibilityDate: '2025-08-05',

  nitro: {
    // El bundle local del servidor hace require() de las colecciones: hay que
    // trazarlas explícitamente o no llegan a .output/server.
    externals: {
      inline: ['@iconify-json/lucide', '@iconify-json/simple-icons'],
    },
  },

  typescript: {
    typeCheck: false,
    strict: true,
  },

  eslint: {
    config: {
      stylistic: true,
    },
  },

  i18n: {
    // Internal authenticated app: no locale prefix in the URL, so company
    // routes such as /e/:empresa stay stable across languages.
    strategy: 'no_prefix',
    defaultLocale: 'es',
    locales: [
      { code: 'es', name: 'Español', language: 'es-ES', file: 'es.json' },
      { code: 'en', name: 'English', language: 'en-US', file: 'en.json' },
    ],
    detectBrowserLanguage: {
      useCookie: true,
      cookieKey: 'morphos_locale',
      redirectOn: 'root',
      alwaysRedirect: false,
    },
  },

  icon: {
    // Los iconos se empaquetan con la app en vez de resolverse contra la API
    // de Iconify: la app funciona sin red y sin llamadas a terceros.
    serverBundle: 'local',
    clientBundle: {
      scan: true,
      includeCustomCollections: true,
    },
  },

  supabase: {
    types: '~~/shared/types/database.ts',
    redirectOptions: {
      login: '/login',
      callback: '/confirm',
      // /api/** se excluye para que las rutas de servidor respondan JSON con su
      // propia comprobación de rol, en vez de un 302 HTML hacia /login.
      exclude: ['/login', '/confirm', '/api/**'],
    },
  },
})
