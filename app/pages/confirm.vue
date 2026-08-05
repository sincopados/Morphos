<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const user = useSupabaseUser()

watch(user, (value) => {
  if (value) navigateTo('/')
}, { immediate: true })
</script>

<template>
  <p class="text-sm text-muted">
    {{ $t('comun.cargando') }}
  </p>
</template>
