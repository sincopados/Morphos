import type { PertenenciaConEmpresa } from '~/composables/useMorphos'
import type { Usuario } from '#shared/types/database'

/**
 * Carga el usuario de MORPHOS y sus pertenencias una sola vez por sesión.
 * A partir de aquí, rol global y roles por empresa están disponibles en
 * cualquier página sin volver a consultar.
 */
export default defineNuxtRouteMiddleware(async (to) => {
  const publicas = ['/login', '/confirm']
  if (publicas.includes(to.path)) return

  // `sub`, no `id`: useSupabaseUser() devuelve claims del JWT (ver useAuthUserId).
  const authId = useAuthUserId()
  if (!authId.value) return

  const usuario = useMorphosUser()
  const pertenencias = usePertenencias()

  if (usuario.value?.id === authId.value) return

  const db = useDb()

  const { data: fila } = await db
    .from('usuarios')
    .select('*')
    .eq('id', authId.value)
    .maybeSingle()

  usuario.value = (fila as Usuario | null) ?? null

  // morphos_core es excluyente: no tiene pertenencias que cargar (ADR-0002).
  if (usuario.value?.rol_global === 'morphos_core') {
    pertenencias.value = []
    return
  }

  const { data: filas } = await db
    .from('pertenencias')
    .select('*, empresas(*)')
    .eq('usuario_id', authId.value)
    .eq('activa', true)

  pertenencias.value = (filas as unknown as PertenenciaConEmpresa[] | null) ?? []
})
