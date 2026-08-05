<script setup lang="ts">
const { t } = useI18n()

useHead({
  titleTemplate: title => (title ? `${title} · MORPHOS` : 'MORPHOS'),
  meta: [{ name: 'description', content: t('app.tagline') }],
})
</script>

<template>
  <UApp>
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>
