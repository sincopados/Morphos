<script setup lang="ts">
import { z } from 'zod'

definePageMeta({ layout: 'auth' })

const { t } = useI18n()
const localePath = useLocalePath()
const { googleAuthEnabled } = useRuntimeConfig().public
const { pending, errorMessage, signInWithPassword, signInWithGoogle } = useAuthActions()

const schema = computed(() => z.object({
  email: z.string().email(t('auth.validation.email')),
  password: z.string().min(8, t('auth.validation.passwordMin'))
}))

const state = reactive({ email: '', password: '' })

useSeoMeta({ title: () => `${t('auth.login.title')} · ${t('app.name')}` })
</script>

<template>
  <div class="space-y-6">
    <div class="space-y-1 text-center">
      <h1 class="text-2xl font-semibold">
        {{ $t('auth.login.title') }}
      </h1>
      <p class="text-sm text-muted">
        {{ $t('auth.login.description') }}
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
      @submit="signInWithPassword(state.email, state.password)"
    >
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
          autocomplete="current-password"
          :placeholder="$t('auth.fields.passwordPlaceholder')"
          class="w-full"
        />
      </UFormField>

      <UButton
        type="submit"
        :label="$t('auth.login.submit')"
        block
        :loading="pending"
      />
    </UForm>

    <p class="text-sm text-muted text-center">
      {{ $t('auth.login.noAccount') }}
      <ULink
        :to="localePath('/registro')"
        class="text-primary font-medium"
      >
        {{ $t('auth.login.createAccount') }}
      </ULink>
    </p>
  </div>
</template>
