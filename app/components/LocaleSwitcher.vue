<script setup lang="ts">
const { locale, locales, setLocale } = useI18n()

const items = computed(() =>
  locales.value.map(l => ({
    label: l.name ?? l.code,
    value: l.code,
  })),
)

const actual = computed({
  get: () => locale.value,
  set: (value: string) => setLocale(value as typeof locale.value),
})
</script>

<template>
  <USelect
    v-model="actual"
    :items="items"
    value-key="value"
    icon="i-lucide-languages"
    size="sm"
    variant="ghost"
    :aria-label="$t('nav.idioma')"
  />
</template>
