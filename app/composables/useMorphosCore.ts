import type { Tables } from '~/types/database.types'

export type CompanyOverview = Tables<'v_company_overview'>

/**
 * Panel de sistema de morphos_core (§3.1): la foto de todas las empresas.
 *
 * No filtra por nada. La consulta trae lo que las policies dejen ver, que para
 * morphos_core es todo y para cualquier otro rol es su propia empresa — la
 * misma vista sirve a los dos sin ramificar la consulta.
 */
export function useMorphosCore() {
  const supabase = useSupabaseClient()

  const companies = ref<CompanyOverview[]>([])
  const pending = ref(false)
  const errorMessage = ref<string | null>(null)

  async function fetchCompanies() {
    pending.value = true
    errorMessage.value = null

    const { data, error } = await supabase
      .from('v_company_overview')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) {
      errorMessage.value = error.message
      pending.value = false
      return
    }

    companies.value = data ?? []
    pending.value = false
  }

  /**
   * Contratar o cancelar la supervision (regla no-negociable #2). Es la unica
   * palanca que decide si morphos_core puede confirmar movimientos en nombre de
   * esa empresa; todo lo demas ya lo puede gestionar sin esto.
   */
  async function setSupervision(companyId: string, contracted: boolean) {
    const { error } = await supabase.rpc('set_supervision_contracted', {
      p_company_id: companyId,
      p_contracted: contracted
    })

    if (error) {
      errorMessage.value = error.message
      return false
    }

    await fetchCompanies()
    return true
  }

  const totals = computed(() => ({
    companies: companies.value.length,
    members: companies.value.reduce((sum, c) => sum + (c.active_members ?? 0), 0),
    workSites: companies.value.reduce((sum, c) => sum + (c.active_work_sites ?? 0), 0),
    weekIncome: companies.value.reduce((sum, c) => sum + Number(c.week_income ?? 0), 0),
    pendingEntries: companies.value.reduce((sum, c) => sum + (c.pending_entries ?? 0), 0),
    supervised: companies.value.filter(c => c.supervision_contracted).length,
    compliancePending: companies.value.filter(c => c.compliance_pending).length
  }))

  return {
    companies,
    totals,
    pending: readonly(pending),
    errorMessage: readonly(errorMessage),
    fetchCompanies,
    setSupervision
  }
}
