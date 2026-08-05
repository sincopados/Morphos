import type { AppRole } from '~/composables/useAppUser'

/**
 * Protege una pagina por rol **en la empresa activa**:
 *
 *   definePageMeta({ middleware: 'require-role', roles: ['owner'] })
 *
 * Es solo para la navegacion: el permiso real lo aplica la RLS en Postgres. Si
 * esto se saltara, la consulta seguiria sin devolver filas ajenas.
 *
 * Que el rol dependa de la empresa activa es lo que hace coherente el
 * multiempresa (§2.1): la misma persona puede entrar a esta pagina con una
 * empresa seleccionada y no con otra.
 */
export default defineNuxtRouteMiddleware(async (to) => {
  const localePath = useLocalePath()
  const { role, needsOnboarding, isMorphosCore, load } = useAppUser()

  await load()

  // morphos_core es super admin de todo el sistema y no pertenece a ninguna
  // empresa (§3.1): pasa antes de cualquier comprobacion de empresa, porque no
  // tener pertenencias es su estado normal, no un onboarding a medias.
  if (isMorphosCore.value) {
    return
  }

  // Cuenta sin ninguna empresa: no tiene sentido mandarla a login (ya tiene
  // sesion), va a crear la suya.
  if (needsOnboarding.value) {
    return navigateTo(localePath('/registro'))
  }

  const allowed = to.meta.roles as AppRole[] | undefined

  if (!allowed?.length) {
    return
  }

  if (!role.value || !allowed.includes(role.value)) {
    return navigateTo(localePath('/dashboard'))
  }
})
