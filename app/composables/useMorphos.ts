import type {
  Empresa,
  Pertenencia,
  UserRole,
  Usuario, Database,
} from '#shared/types/database'

export function useDb() {
  return useSupabaseClient<Database>()
}

/**
 * El id del usuario autenticado.
 *
 * Ojo: `useSupabaseUser()` de @nuxtjs/supabase v2 no devuelve un `User`, sino
 * los claims del JWT (`auth.getClaims()`). El identificador es `sub`, no `id`
 * — usar `.id` produce consultas con `eq.undefined` que la API rechaza con 400.
 */
export function useAuthUserId() {
  const claims = useSupabaseUser()
  return computed(() => (claims.value?.sub as string | undefined) ?? null)
}

export interface PertenenciaConEmpresa extends Pertenencia {
  empresas: Empresa | null
}

/** Fila de `usuarios` con sus pertenencias, como la lee el Dashboard Global. */
export interface UsuarioConPertenencias extends Usuario {
  pertenencias: PertenenciaConEmpresa[]
}

/**
 * Pertenencia con la persona detrás, como la lee el equipo de una empresa.
 *
 * `bloques` llega como agregado de PostgREST (`bloques(count)`) y dice cuántos
 * fichajes cuelgan de ella. Importa porque `bloques.pertenencia_id` borra en
 * cascada: sin ese dato no se puede saber si eliminar a alguien destruiría su
 * historial de trabajo.
 */
export interface MiembroEquipo extends Pertenencia {
  usuarios: Usuario | null
  bloques?: { count: number }[]
}

/** Fichajes colgando de una pertenencia. 0 = se puede eliminar sin perder nada. */
export function bloquesDe(miembro: MiembroEquipo) {
  return miembro.bloques?.[0]?.count ?? 0
}

/**
 * El usuario de MORPHOS (fila `usuarios`), no el de `auth`. Aquí vive el rol
 * global; los roles por empresa viven en las pertenencias.
 */
export function useMorphosUser() {
  return useState<Usuario | null>('morphos:usuario', () => null)
}

export function useEsMorphosCore() {
  const usuario = useMorphosUser()
  return computed(() => usuario.value?.rol_global === 'morphos_core')
}

/** Pertenencias del usuario, con su empresa. Vacío para `morphos_core`. */
export function usePertenencias() {
  return useState<PertenenciaConEmpresa[]>('morphos:pertenencias', () => [])
}

/**
 * La empresa del selector. Todo lo que ve el usuario cuelga de aquí: cambiarla
 * cambia rol, tarifa, saldo e historial por completo.
 */
/**
 * La empresa que `morphos_core` está gestionando.
 *
 * Existe porque el rol es excluyente (ADR-0002): no tiene pertenencias, así que
 * no hay de dónde deducir la empresa del selector. La carga el middleware
 * `empresa` a partir del slug de la ruta.
 */
export function useEmpresaCore() {
  return useState<Empresa | null>('morphos:empresaCore', () => null)
}

/**
 * Resuelve una empresa a partir de un slug, sin tocar la ruta actual.
 *
 * Existe separado de `useEmpresaActiva` porque un middleware NO puede usar
 * `useRoute()`: allí devuelve la ruta que se abandona, no la de destino, y el
 * slug saldría vacío justo cuando se navega hacia una empresa. El middleware
 * pasa el slug de `to` y usa esto.
 */
export function empresaDeSlug(slug: string | undefined) {
  const pertenencias = usePertenencias()
  const empresaCore = useEmpresaCore()

  const pertenencia = pertenencias.value.find(p => p.empresas?.slug === slug) ?? null

  // Para todos, la empresa sale de su pertenencia. Para `morphos_core`, de la
  // que cargó el middleware — solo si coincide con el slug pedido, para no
  // arrastrar la empresa anterior mientras se navega a otra.
  const empresa: Empresa | null = pertenencia?.empresas
    ?? (empresaCore.value?.slug === slug ? empresaCore.value : null)

  return { pertenencia, empresa, rol: pertenencia?.rol ?? null }
}

export function useEmpresaActiva() {
  const route = useRoute()

  const slug = computed(() => {
    const value = route.params.slug
    return Array.isArray(value) ? value[0] : value
  })

  const resuelta = computed(() => empresaDeSlug(slug.value))

  return {
    slug,
    pertenencia: computed(() => resuelta.value.pertenencia),
    empresa: computed(() => resuelta.value.empresa),
    rol: computed<UserRole | null>(() => resuelta.value.rol),
    bloqueada: computed(() => resuelta.value.empresa?.estado === 'bloqueada'),
  }
}

/** Quién ve el dashboard de empresa y sus totales (docs/spec/20 §3). */
export function useGestionaEmpresa() {
  const { rol } = useEmpresaActiva()
  const esCore = useEsMorphosCore()
  return computed(
    () => esCore.value || rol.value === 'owner' || rol.value === 'administrador',
  )
}

export function useFormatoDinero() {
  const { locale } = useI18n()
  return (importe: number, moneda = 'EUR') =>
    new Intl.NumberFormat(locale.value === 'en' ? 'en-US' : 'es-ES', {
      style: 'currency',
      currency: moneda,
      maximumFractionDigits: 2,
    }).format(importe ?? 0)
}

export function useFormatoFecha() {
  const { locale } = useI18n()
  return (fecha: string | null) => {
    if (!fecha) return '—'
    return new Intl.DateTimeFormat(locale.value === 'en' ? 'en-US' : 'es-ES', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(new Date(fecha))
  }
}

/** Semana lunes–domingo, la que usa el bloque "Generado en la semana". */
export function semanaEnCurso(desde = new Date()) {
  const inicio = new Date(desde)
  const dia = (inicio.getDay() + 6) % 7
  inicio.setDate(inicio.getDate() - dia)
  inicio.setHours(0, 0, 0, 0)

  const fin = new Date(inicio)
  fin.setDate(fin.getDate() + 7)

  return { inicio, fin }
}

export function isoDate(date: Date) {
  return date.toISOString().slice(0, 10)
}

/** Horas de un bloque: día completo = 8 h, medio día = 4 h, más el ajuste. */
export function horasDeBloque(tipo: 'dia_completo' | 'medio_dia', ajuste: number) {
  return (tipo === 'dia_completo' ? 8 : 4) + (ajuste ?? 0)
}
