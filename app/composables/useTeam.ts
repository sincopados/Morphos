import type { Tables } from '~/types/database.types'
import type { InvitableRole, Profile } from '~/composables/useAppUser'

export type WorkSite = Tables<'work_sites'>

/** Una pertenencia con la persona detras, tal como se lista en pantalla. */
export type TeamMember = Tables<'company_members'> & { profiles: Profile | null }

export interface InviteInput {
  fullName: string
  email: string
  role: InvitableRole
  fullDayValue?: number | null
  halfDayValue?: number | null
}

/**
 * Gestion de equipo de la empresa activa. Filtra por `company_id` porque la
 * RLS deja ver todas las empresas de las que la persona es miembro (§2.1): el
 * filtro es lo que hace que la pantalla muestre una sola empresa, no lo que da
 * seguridad. Dentro de esa empresa es la policy la que decide a quien se ve —
 * el owner ve a todo su equipo, el administrador solo a la gente de sus obras.
 */
export function useTeam() {
  const supabase = useSupabaseClient()
  const { activeCompanyId } = useAppUser()

  const members = ref<TeamMember[]>([])
  const workSites = ref<WorkSite[]>([])
  const adminSites = ref<Record<string, string[]>>({})
  const pending = ref(false)
  const errorMessage = ref<string | null>(null)

  async function fetchTeam() {
    const companyId = activeCompanyId.value

    if (!companyId) {
      members.value = []
      workSites.value = []
      adminSites.value = {}
      return
    }

    pending.value = true
    errorMessage.value = null

    const [team, sites, assignments] = await Promise.all([
      supabase
        .from('company_members')
        .select('*, profiles(*)')
        .eq('company_id', companyId)
        .order('created_at'),
      supabase.from('work_sites').select('*').eq('company_id', companyId).order('name'),
      supabase
        .from('admin_work_sites')
        .select('member_id, work_site_id')
        .eq('company_id', companyId)
    ])

    if (team.error) {
      errorMessage.value = team.error.message
      pending.value = false
      return
    }

    members.value = (team.data ?? []) as TeamMember[]
    workSites.value = sites.data ?? []

    adminSites.value = (assignments.data ?? []).reduce<Record<string, string[]>>((acc, row) => {
      (acc[row.member_id] ||= []).push(row.work_site_id)
      return acc
    }, {})

    pending.value = false
  }

  /**
   * El alta va por RPC y no por insert directo: la funcion reutiliza el perfil
   * si el correo ya existe (la persona puede estar en otra empresa), deriva el
   * profile_type del rol y rechaza que alguien entre dos veces a la misma.
   */
  async function invite(input: InviteInput): Promise<boolean> {
    const companyId = activeCompanyId.value

    if (!companyId) {
      return false
    }

    pending.value = true
    errorMessage.value = null

    const { error } = await supabase.rpc('invite_team_member', {
      p_company_id: companyId,
      p_full_name: input.fullName,
      p_email: input.email,
      p_role: input.role,
      p_full_day_value: input.fullDayValue ?? undefined,
      p_half_day_value: input.halfDayValue ?? undefined
    })

    if (error) {
      errorMessage.value = error.message
      pending.value = false
      return false
    }

    await fetchTeam()
    return true
  }

  /**
   * Alta y baja logica: `status`, no delete. El historico del saldo depende de
   * que la pertenencia siga existiendo. Solo afecta a esta empresa: la misma
   * persona sigue activa en las demas.
   */
  async function setStatus(memberId: string, status: 'activo' | 'inactivo') {
    const { error } = await supabase
      .from('company_members')
      .update({ status })
      .eq('id', memberId)

    if (error) {
      errorMessage.value = error.message
      return false
    }

    await fetchTeam()
    return true
  }

  /** ADR-0004: desbloquear el check-in tras el 3er rechazo. */
  async function unblockCheckin(memberId: string) {
    const { error } = await supabase
      .from('company_members')
      .update({ checkin_blocked: false, checkin_blocked_at: null })
      .eq('id', memberId)

    if (error) {
      errorMessage.value = error.message
      return false
    }

    await fetchTeam()
    return true
  }

  /** Reemplaza de una vez las obras que gestiona un administrador (§5.10). */
  async function assignWorkSites(memberId: string, workSiteIds: string[]) {
    const { error } = await supabase.rpc('set_admin_work_sites', {
      p_member_id: memberId,
      p_work_site_ids: workSiteIds
    })

    if (error) {
      errorMessage.value = error.message
      return false
    }

    await fetchTeam()
    return true
  }

  // Cambiar de empresa recarga el equipo: la pantalla es siempre de una sola.
  watch(activeCompanyId, () => fetchTeam())

  return {
    members,
    workSites,
    adminSites,
    pending: readonly(pending),
    errorMessage: readonly(errorMessage),
    fetchTeam,
    invite,
    setStatus,
    unblockCheckin,
    assignWorkSites
  }
}
