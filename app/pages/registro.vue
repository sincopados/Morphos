<script setup lang="ts">
import { z } from 'zod'

definePageMeta({ layout: 'auth' })

const { t } = useI18n()
const localePath = useLocalePath()
const { googleAuthEnabled } = useRuntimeConfig().public
const { pending, errorMessage, signUpWithPassword, signInWithGoogle } = useAuthActions()

const schema = computed(() => z.object({
  companyName: z.string().min(2, t('auth.validation.companyName')),
  email: z.string().email(t('auth.validation.email')),
  password: z.string().min(8, t('auth.validation.passwordMin')),
  referredByCode: z.string().optional()
}))

const state = reactive({
  companyName: '',
  email: '',
  password: '',
  referredByCode: ''
})

// Con confirmacion por correo activada el alta no abre sesion: hay que
// decirle al usuario que vaya a su bandeja en vez de dejarlo esperando.
const awaitingConfirmation = ref(false)

async function onSubmit() {
  awaitingConfirmation.value = await signUpWithPassword(state.email, state.password, {
    companyName: state.companyName,
    referredByCode: state.referredByCode
  })
}

useSeoMeta({ title: () => `${t('auth.register.title')} · ${t('app.name')}` })
</script>

<template>
  <div
    v-if="awaitingConfirmation"
    class="space-y-4 text-center"
  >
    <UIcon
      name="i-lucide-mail-check"
      class="size-10 text-primary"
    />
    <h1 class="text-2xl font-semibold">
      {{ $t('auth.register.checkEmailTitle') }}
    </h1>
    <p class="text-sm text-muted">
      {{ $t('auth.register.checkEmailBody', { email: state.email }) }}
    </p>
    <ULink
      :to="localePath('/login')"
      class="text-primary text-sm font-medium"
    >
      {{ $t('auth.confirm.backToLogin') }}
    </ULink>
  </div>

  <div
    v-else
    class="space-y-6"
  >
    <div class="space-y-1 text-center">
      <h1 class="text-2xl font-semibold">
        {{ $t('auth.register.title') }}
      </h1>
      <p class="text-sm text-muted">
        {{ $t('auth.register.description') }}
      </p>
    </div>

    <UButton
      v-if="googleAuthEnabled"
      icon="i-simple-icons-google"
      :label="$t('auth.google')"
      color="neutral"
      variant="subtle"
      block
      :disabled="pending"
      @click="signInWithGoogle"
    />

    <USeparator
      v-if="googleAuthEnabled"
      :label="$t('auth.separator')"
    />

    <UAlert
      v-if="errorMessage"
      icon="i-lucide-triangle-alert"
      color="error"
      variant="subtle"
      :description="errorMessage"
    />

    <UForm
      :schema="schema"
      :state="state"
      class="space-y-4"
      @submit="onSubmit"
    >
      <UFormField
        name="companyName"
        :label="$t('auth.fields.companyName')"
        required
      >
        <UInput
          v-model="state.companyName"
          autocomplete="organization"
          :placeholder="$t('auth.fields.companyNamePlaceholder')"
          class="w-full"
        />
      </UFormField>

      <UFormField
        name="email"
        :label="$t('auth.fields.email')"
        required
      >
        <UInput
          v-model="state.email"
          type="email"
          autocomplete="email"
          :placeholder="$t('auth.fields.emailPlaceholder')"
          class="w-full"
        />
      </UFormField>

      <UFormField
        name="password"
        :label="$t('auth.fields.password')"
        required
      >
        <UInput
          v-model="state.password"
          type="password"
          autocomplete="new-password"
          :placeholder="$t('auth.fields.passwordPlaceholder')"
          class="w-full"
        />
      </UFormField>

      <UFormField
        name="referredByCode"
        :label="$t('auth.fields.referralCode')"
        :hint="$t('auth.fields.optional')"
      >
        <UInput
          v-model="state.referredByCode"
          :placeholder="$t('auth.fields.referralCodePlaceholder')"
          class="w-full"
        />
      </UFormField>

      <UButton
        type="submit"
        :label="$t('auth.register.submit')"
        block
        :loading="pending"
      />
    </UForm>

    <p class="text-sm text-muted text-center">
      {{ $t('auth.register.hasAccount') }}
      <ULink
        :to="localePath('/login')"
        class="text-primary font-medium"
      >
        {{ $t('auth.register.signIn') }}
      </ULink>
    </p>
  </div>
</template>
