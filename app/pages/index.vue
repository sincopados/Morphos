<script setup lang="ts">
const { t } = useI18n()
</script>

<template>
  <div>
    <UPageHero
      :title="t('home.title')"
      :description="t('home.description')"
    />
  </div>
</template>
