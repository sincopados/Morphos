<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const supabase = useSupabaseClient()
const { t } = useI18n()

const email = ref('')
const password = ref('')
const cargando = ref(false)
const error = ref('')
const aviso = ref('')

// El middleware manda aquí a quien tenga la cuenta desactivada.
const inactivo = computed(() => useRoute().query.estado === 'inactivo')

useHead({ title: () => t('auth.entrar') })

async function conPassword() {
  cargando.value = true
  error.value = ''
  aviso.value = ''

  const { error: err } = await supabase.auth.signInWithPassword({
    email: email.value,
    password: password.value,
  })

  cargando.value = false
  if (err) {
    error.value = err.message
    return
  }
  await navigateTo('/')
}

async function conGoogle() {
  error.value = ''
  const { error: err } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: `${window.location.origin}/confirm` },
  })
  if (err) error.value = err.message
}
</script>

<template>
  <div class="w-full max-w-sm">
    <div class="mb-8 text-center">
      <p class="text-3xl font-semibold tracking-tight text-primary">
        MORPHOS
      </p>
      <p class="mt-2 text-sm text-muted">
        {{ $t('app.tagline') }}
      </p>
    </div>

    <UCard>
      <form
        v-auto-animate
        class="flex flex-col gap-4"
        @submit.prevent="conPassword"
      >
        <UFormField
          :label="$t('auth.email')"
          name="email"
        >
          <UInput
            v-model="email"
            type="email"
            autocomplete="email"
            icon="i-lucide-mail"
            required
            class="w-full"
          />
        </UFormField>

        <UFormField
          :label="$t('auth.password')"
          name="password"
        >
          <UInput
            v-model="password"
            type="password"
            autocomplete="current-password"
            icon="i-lucide-lock"
            required
            class="w-full"
          />
        </UFormField>

        <p
          v-if="inactivo"
          class="flex items-start gap-2 rounded-lg bg-warning/10 px-3 py-2 text-sm text-warning"
        >
          <UIcon
            name="i-lucide-user-x"
            class="mt-0.5 size-4 shrink-0"
          />
          {{ $t('auth.cuentaInactiva') }}
        </p>
        <p
          v-if="error"
          class="rounded-lg bg-error/10 px-3 py-2 text-sm text-error"
        >
          {{ error }}
        </p>
        <p
          v-if="aviso"
          class="rounded-lg bg-success/10 px-3 py-2 text-sm text-success"
        >
          {{ aviso }}
        </p>

        <UButton
          type="submit"
          block
          :loading="cargando"
          :label="$t('auth.entrar')"
        />
      </form>

      <div class="my-4 flex items-center gap-3 text-xs text-dimmed">
        <span class="h-px flex-1 bg-default" />
        {{ $t('auth.oBien') }}
        <span class="h-px flex-1 bg-default" />
      </div>

      <UButton
        block
        color="neutral"
        variant="subtle"
        icon="i-simple-icons-google"
        :label="$t('auth.conGoogle')"
        @click="conGoogle"
      />
    </UCard>

    <div class="mt-6 flex justify-center">
      <LocaleSwitcher />
    </div>
  </div>
</template>
