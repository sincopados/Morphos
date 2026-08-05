<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const esCore = useEsMorphosCore()
const pertenencias = usePertenencias()

// morphos_core no pertenece a ninguna empresa: su casa es el Dashboard Global.
if (esCore.value) {
  await navigateTo('/global')
}
else if (pertenencias.value.length === 1) {
  await navigateTo(`/e/${pertenencias.value[0]!.empresas?.slug}`)
}
else {
  await navigateTo('/empresas')
}
</script>

<template>
  <p class="text-sm text-muted">
    {{ $t('comun.cargando') }}
  </p>
</template>
