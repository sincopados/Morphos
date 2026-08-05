import type { Tables } from '~/types/database.types'

export type Profile = Tables<'profiles'>
export type Company = Tables<'companies'>
export type Membership = Tables<'company_members'>

/** Una pertenencia con la empresa a la que corresponde, tal como llega del join. */
export type MembershipWithCompany = Membership & { companies: Company | null }

/**
 * Roles tal como los define CONTEXT.md §3.1. La lista vive aqui y no
 * en un enum de Postgres a proposito: el check de la tabla ya es la fuente de
 * verdad, y duplicarlo como enum obligaria a una migracion para cada cambio.
 * El precio es que `role` llega como `string`, asi que la union literal se
 * declara aqui en vez de derivarla del tipo generado.
 */
export const COMPANY_ROLES = ['owner', 'administrador', 'trabajador', 'vendedor', 'afiliado'] as const
export const PLATFORM_ROLES = ['morphos_core', 'tutor', 'asesor'] as const

/** Los que un owner puede invitar a su empresa (los demas son de plataforma). */
export const INVITABLE_ROLES = ['administrador', 'trabajador', 'vendedor', 'afiliado'] as const

export type AppRole = (typeof COMPANY_ROLES)[number]
export type PlatformRole = (typeof PLATFORM_ROLES)[number]
export type InvitableRole = (typeof INVITABLE_ROLES)[number]

/** Cookie de la empresa activa: sobrevive al recargar y viaja al servidor. */
const ACTIVE_COMPANY_COOKIE = 'morphos_company'

/**
 * La sesion de la app, en el modelo de pertenencias de §2.1:
 *
 *   profile     — quien eres. Uno solo, aunque trabajes en varias empresas.
 *   memberships — que eres en cada empresa.
 *   membership  — la pertenencia de la empresa que tengas seleccionada.
 *
 * El rol siempre sale de `membership`, nunca del perfil, porque el rol es de la
 * pertenencia: alguien puede ser `owner` en su empresa y `trabajador` en otra.
 *
 * Cambiar de empresa es un cambio de interfaz, no de permisos: la RLS deja ver
 * todas las empresas de las que eres miembro y es la consulta la que filtra.
 * Nada de lo que devuelve esto autoriza por si mismo.
 */
export function useAppUser() {
  const supabase = useSupabaseClient()
  const authUser = useSupabaseUser()

  const profile = useState<Profile | null>('app-profile', () => null)
  const memberships = useState<MembershipWithCompany[]>('app-memberships', () => [])
  const pending = useState<boolean>('app-session-pending', () => false)
  const activeCompanyId = useCookie<string | null>(ACTIVE_COMPANY_COOKIE, {
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 365
  })

  async function load(force = false) {
    if (!authUser.value) {
      profile.value = null
      memberships.value = []
      return
    }

    if (profile.value && !force) {
      return
    }

    pending.value = true

    // Siempre por RPC: garantiza que la persona tenga exactamente un perfil y
    // reclama la invitacion si alguien la dio de alta antes de que se registrara.
    const { data: profileId, error } = await supabase.rpc('ensure_profile')

    if (error || !profileId) {
      profile.value = null
      memberships.value = []
      pending.value = false
      return
    }

    const [{ data: profileRow }, { data: membershipRows }] = await Promise.all([
      supabase.from('profiles').select('*').eq('id', profileId).maybeSingle(),
      supabase
        .from('company_members')
        .select('*, companies(*)')
        .eq('profile_id', profileId)
        .eq('status', 'activo')
        .order('created_at')
    ])

    profile.value = profileRow ?? null
    memberships.value = (membershipRows ?? []) as MembershipWithCompany[]

    // La empresa guardada puede haber dejado de valer (te sacaron del equipo,
    // o es de otra cuenta que uso este navegador): se cae a la primera.
    // morphos_core queda fuera de esta comprobacion: supervisa empresas a las
    // que no pertenece, asi que su empresa activa nunca sale de `memberships`.
    if (profile.value?.platform_role !== 'morphos_core') {
      const stored = activeCompanyId.value
      const isValid = stored && memberships.value.some(m => m.company_id === stored)

      if (!isValid) {
        activeCompanyId.value = memberships.value[0]?.company_id ?? null
      }
    }

    pending.value = false
  }

  const membership = computed<MembershipWithCompany | null>(() =>
    memberships.value.find(m => m.company_id === activeCompanyId.value) ?? null
  )

  const company = computed<Company | null>(() => membership.value?.companies ?? null)
  const role = computed<AppRole | null>(() => (membership.value?.role as AppRole) ?? null)

  /** Equipo interno de MORPHOS: transversal, no depende de la empresa activa. */
  const isMorphosCore = computed(() => profile.value?.platform_role === 'morphos_core')

  /**
   * Roles de plataforma (§3.2): morphos_core, tutor y asesor. No pertenecen a
   * ninguna empresa por diseno, asi que "sin pertenencias" es su estado normal
   * y no significa que les falte completar el onboarding.
   */
  const isPlatformUser = computed(() => !!profile.value?.platform_role)

  /**
   * Cambia la empresa activa. Para el resto de la gente solo vale una empresa
   * de la que sea miembro; morphos_core puede entrar en cualquiera, porque
   * supervisa sin pertenecer (§3.1). Aun asi la RLS es la que decide: poner un
   * id aqui no da acceso a nada por si solo.
   */
  function switchCompany(companyId: string) {
    if (isMorphosCore.value || memberships.value.some(m => m.company_id === companyId)) {
      activeCompanyId.value = companyId
    }
  }

  return {
    profile,
    memberships,
    membership,
    company,
    activeCompanyId,
    role,
    pending: readonly(pending),
    load,
    switchCompany,
    isPlatformUser,
    /**
     * La cuenta existe pero no pertenece a ninguna empresa y deberia: le falta
     * crear la suya. Un rol de plataforma nunca cae aqui.
     */
    needsOnboarding: computed(
      () => !!profile.value && memberships.value.length === 0 && !isPlatformUser.value
    ),
    hasSeveralCompanies: computed(() => memberships.value.length > 1),
    isMorphosCore,
    /** Alcance total sobre la empresa activa (§3.1). */
    isOwner: computed(() => role.value === 'owner'),
    /** Solo alcanza las obras que el owner le asigno (§5.10). */
    isAdministrador: computed(() => role.value === 'administrador'),
    isTrabajador: computed(() => role.value === 'trabajador'),
    /** Quien ve el dashboard de empresa: owner y administrador (§4.3). */
    canSeeDashboard: computed(
      () => role.value === 'owner' || role.value === 'administrador' || isMorphosCore.value
    ),
    hasRole: (...roles: AppRole[]) => !!role.value && roles.includes(role.value)
  }
}
