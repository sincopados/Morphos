<script setup lang="ts">
const { t } = useI18n()
const localePath = useLocalePath()
const user = useSupabaseUser()
const { canSeeDashboard, isMorphosCore, load } = useAppUser()

// El rol vive en public.users, no en la sesion de auth: hay que cargarlo para
// saber que puede ver esta persona (§4.3).
await load()

useSeoMeta({ title: () => `${t('dashboard.title')} · ${t('app.name')}` })
</script>

<template>
  <UContainer class="py-12 space-y-4">
    <h1 class="text-2xl font-semibold">
      {{ $t('dashboard.title') }}
    </h1>

    <p class="text-sm text-muted">
      {{ $t('dashboard.signedInAs', { email: user?.email ?? '' }) }}
    </p>

    <div class="flex flex-wrap gap-2">
      <UButton
        v-if="canSeeDashboard"
        icon="i-lucide-users"
        color="neutral"
        variant="subtle"
        :to="localePath('/equipo')"
        :label="$t('team.title')"
      />

      <!-- El panel de sistema es de morphos_core: vive aparte del dashboard de
           empresa porque no mira una empresa, sino todas (§4.4). -->
      <UButton
        v-if="isMorphosCore"
        icon="i-lucide-shield"
        :to="localePath('/morphos')"
        :label="$t('morphos.title')"
      />
    </div>

    <UAlert
      icon="i-lucide-construction"
      color="neutral"
      variant="subtle"
      :description="$t('dashboard.placeholder')"
    />
  </UContainer>
</template>
