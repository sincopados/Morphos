<script setup lang="ts">
const { locale, locales, setLocale } = useI18n()

// Solo hay dos idiomas, asi que un boton que alterna al otro basta.
const other = computed(() =>
  locales.value.find(l => l.code !== locale.value) ?? locales.value[0]
)
</script>

<template>
  <UButton
    v-if="other"
    :label="other.code.toUpperCase()"
    :aria-label="other.name"
    color="neutral"
    variant="ghost"
    @click="setLocale(other.code)"
  />
</template>
