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

  routeRules: {
    '/': { prerender: true }
  },

  compatibilityDate: '2026-06-30',

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
