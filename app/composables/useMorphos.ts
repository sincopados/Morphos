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
export function useEmpresaActiva() {
  const route = useRoute()
  const pertenencias = usePertenencias()

  const slug = computed(() => {
    const value = route.params.slug
    return Array.isArray(value) ? value[0] : value
  })

  const pertenencia = computed(
    () => pertenencias.value.find(p => p.empresas?.slug === slug.value) ?? null,
  )

  return {
    slug,
    pertenencia,
    empresa: computed(() => pertenencia.value?.empresas ?? null),
    rol: computed<UserRole | null>(() => pertenencia.value?.rol ?? null),
    bloqueada: computed(() => pertenencia.value?.empresas?.estado === 'bloqueada'),
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
