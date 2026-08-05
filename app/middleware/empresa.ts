/**
 * Guarda las rutas de una empresa concreta.
 *
 * Con la empresa bloqueada, `owner` y `administrador` quedan fuera y ven la
 * pantalla de renovación; `trabajador`, `vendedor` y `afiliado` conservan la
 * lectura de su propio saldo (docs/spec/30-comercial.md §3).
 */
export default defineNuxtRouteMiddleware((to) => {
  const { pertenencia, empresa, rol, slug } = useEmpresaActiva()
  const esCore = useEsMorphosCore()

  if (esCore.value) return

  if (!pertenencia.value) {
    return navigateTo('/empresas')
  }

  if (empresa.value?.estado !== 'bloqueada') return

  const esPantallaDeBloqueo = to.path.endsWith('/bloqueada')
  const esSaldo = to.path.endsWith('/saldo')
  const gestiona = rol.value === 'owner' || rol.value === 'administrador'

  if (esPantallaDeBloqueo) return
  if (!gestiona && esSaldo) return

  return navigateTo(`/e/${slug.value}/bloqueada`)
})
