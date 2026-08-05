<script setup lang="ts">
definePageMeta({ layout: 'auth' })

const { t } = useI18n()
const localePath = useLocalePath()
const user = useSupabaseUser()
const redirect = useSupabaseCookieRedirect()
const { load } = useAppUser()

// El cliente de @supabase/ssr canjea el codigo de la URL por una sesion al
// cargar, asi que aqui solo esperamos a que aparezca el usuario. Si no llega,
// el enlace estaba vencido o mal formado.
const failed = ref(false)

onMounted(() => {
  const stop = watch(user, async (value) => {
    if (!value) return
    stop()
    clearTimeout(timer)
    // Materializa el perfil antes de seguir: si alguien la invito antes de que
    // se registrara, aqui es donde reclama esa invitacion y sus pertenencias.
    await load(true)
    await navigateTo(redirect.pluck() || localePath('/'), { replace: true })
  }, { immediate: true })

  const timer = setTimeout(() => {
    stop()
    failed.value = true
  }, 10000)

  onScopeDispose(() => clearTimeout(timer))
})

useSeoMeta({ title: () => `${t('auth.confirm.verifying')} · ${t('app.name')}` })
</script>

<template>
  <div class="space-y-4 text-center">
    <template v-if="failed">
      <UIcon
        name="i-lucide-triangle-alert"
        class="size-10 text-error"
      />
      <p class="text-sm text-muted">
        {{ $t('auth.confirm.failed') }}
      </p>
      <UButton
        :to="localePath('/login')"
        :label="$t('auth.confirm.backToLogin')"
        color="neutral"
        variant="subtle"
      />
    </template>

    <template v-else>
      <UIcon
        name="i-lucide-loader-circle"
        class="size-10 text-primary animate-spin"
      />
      <p class="text-sm text-muted">
        {{ $t('auth.confirm.verifying') }}
      </p>
    </template>
  </div>
</template>
