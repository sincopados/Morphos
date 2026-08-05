<script setup lang="ts">
const { t } = useI18n()
const user = useSupabaseUser()

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

    <UAlert
      icon="i-lucide-construction"
      color="neutral"
      variant="subtle"
      :description="$t('dashboard.placeholder')"
    />
  </UContainer>
</template>
