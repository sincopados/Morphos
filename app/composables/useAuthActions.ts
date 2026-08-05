/**
 * Forma minima de un error de auth de Supabase. Se declara aqui en vez de
 * importar el tipo de `@supabase/supabase-js`, que es una dependencia
 * transitiva del modulo y no resuelve bajo el node_modules estricto de pnpm.
 */
interface SupabaseAuthError {
  code?: string
  message: string
}

/** Datos de la Pantalla 1 del onboarding que se capturan junto al alta. */
export interface SignupDraft {
  companyName?: string
  referredByCode?: string
}

/**
 * Supabase devuelve sus errores en ingles y sin traducir. Mapeamos los codigos
 * que un usuario puede provocar de verdad; el resto cae en un mensaje generico
 * para no filtrar detalle interno en pantalla.
 */
const ERROR_KEYS: Record<string, string> = {
  invalid_credentials: 'auth.errors.invalidCredentials',
  email_not_confirmed: 'auth.errors.emailNotConfirmed',
  user_already_exists: 'auth.errors.userExists',
  email_exists: 'auth.errors.userExists',
  weak_password: 'auth.errors.weakPassword',
  email_address_invalid: 'auth.errors.invalidEmail',
  over_request_rate_limit: 'auth.errors.rateLimit',
  over_email_send_rate_limit: 'auth.errors.rateLimit'
}

export function useAuthActions() {
  const supabase = useSupabaseClient()
  const localePath = useLocalePath()
  const { t } = useI18n()
  const redirect = useSupabaseCookieRedirect()

  const pending = ref(false)
  const errorMessage = ref<string | null>(null)

  function describe(error: SupabaseAuthError): string {
    const key = error.code ? ERROR_KEYS[error.code] : undefined
    return key ? t(key) : t('auth.errors.generic')
  }

  /** Vuelve a donde el usuario queria ir antes de que el guard lo interceptara. */
  async function goToIntendedDestination() {
    // Antes de navegar, la sesion tiene que tener perfil y pertenencias: es lo
    // que reclama una invitacion pendiente y lo que fija la empresa activa.
    await useAppUser().load(true)
    await navigateTo(redirect.pluck() || localePath('/'))
  }

  async function signInWithPassword(email: string, password: string) {
    pending.value = true
    errorMessage.value = null

    const { error } = await supabase.auth.signInWithPassword({ email, password })

    if (error) {
      errorMessage.value = describe(error)
      pending.value = false
      return
    }

    await goToIntendedDestination()
    pending.value = false
  }

  /**
   * Devuelve true cuando el alta quedo pendiente de confirmar por correo, para
   * que la pagina muestre el aviso en vez de asumir que ya hay sesion.
   *
   * `signupDraft` viaja en el user_metadata porque el alta por correo saca al
   * usuario de la app y cualquier estado en memoria se pierde. Es solo para
   * prellenar el onboarding: el usuario puede editarlo a voluntad, asi que
   * nunca debe usarse como fuente de verdad ni para decisiones de permisos.
   * `bootstrap_company` sigue recibiendo cada valor explicitamente.
   */
  async function signUpWithPassword(
    email: string,
    password: string,
    signupDraft: SignupDraft = {}
  ): Promise<boolean> {
    pending.value = true
    errorMessage.value = null

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}${localePath('/confirm')}`,
        data: {
          company_name: signupDraft.companyName || null,
          referred_by_code: signupDraft.referredByCode || null
        }
      }
    })

    if (error) {
      errorMessage.value = describe(error)
      pending.value = false
      return false
    }

    pending.value = false

    // Con confirmacion por correo activada no llega sesion en la respuesta.
    if (!data.session) {
      return true
    }

    await goToIntendedDestination()
    return false
  }

  async function signInWithGoogle() {
    pending.value = true
    errorMessage.value = null

    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}${localePath('/confirm')}`
      }
    })

    // Si no hay error el navegador ya se fue a Google; solo llegamos aqui si fallo.
    if (error) {
      errorMessage.value = describe(error)
      pending.value = false
    }
  }

  async function signOut() {
    await supabase.auth.signOut()
    await navigateTo(localePath('/login'))
  }

  return {
    pending: readonly(pending),
    errorMessage: readonly(errorMessage),
    signInWithPassword,
    signUpWithPassword,
    signInWithGoogle,
    signOut
  }
}
