import type { AppRole } from '~/composables/useAppUser'

/** Roles admitidos por el middleware `require-role` en definePageMeta. */
declare module '#app' {
  interface PageMeta {
    roles?: AppRole[]
  }
}

export {}
