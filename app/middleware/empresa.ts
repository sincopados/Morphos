import type { Empresa } from '#shared/types/database'

/**
 * Guarda las rutas de una empresa concreta.
 *
 * Con la empresa bloqueada, `owner` y `administrador` quedan fuera y ven la
 * pantalla de renovación; `trabajador`, `vendedor` y `afiliado` conservan la
 * lectura de su propio saldo (docs/spec/30-comercial.md §3).
 */
export default defineNuxtRouteMiddleware(async (to) => {
  // El slug se toma de `to`, nunca de `useRoute()`: dentro de un middleware
  // esa función devuelve la ruta que se abandona (NUXT_E2005), así que al
  // entrar en una empresa desde el selector saldría vacío.
  const slugParam = to.params.slug
  const slug = Array.isArray(slugParam) ? slugParam[0] : slugParam

  const esCore = useEsMorphosCore()

  if (esCore.value) {
    // `morphos_core` no pertenece a ninguna empresa, así que no puede
    // deducirla del selector: se carga por slug al entrar a gestionarla
    // (docs/spec/40-dashboard-global.md §3).
    const empresaCore = useEmpresaCore()
    if (slug && empresaCore.value?.slug !== slug) {
      const { data } = await useDb()
        .from('empresas')
        .select('*')
        .eq('slug', slug)
        .maybeSingle()

      empresaCore.value = (data as Empresa | null) ?? null
    }

    if (!empresaCore.value) {
      return navigateTo('/global/empresas')
    }

    // El bloqueo por impago no aplica al equipo interno: entra igualmente,
    // porque parte de su trabajo es resolver justo ese impago.
    return
  }

  const { pertenencia, empresa, rol } = empresaDeSlug(slug)

  if (!pertenencia) {
    return navigateTo('/empresas')
  }

  if (empresa?.estado !== 'bloqueada') return

  const esPantallaDeBloqueo = to.path.endsWith('/bloqueada')
  const esSaldo = to.path.endsWith('/saldo')
  const gestiona = rol === 'owner' || rol === 'administrador'

  if (esPantallaDeBloqueo) return
  if (!gestiona && esSaldo) return

  return navigateTo(`/e/${slug}/bloqueada`)
})
