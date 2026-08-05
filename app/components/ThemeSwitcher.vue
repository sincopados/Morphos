<script setup lang="ts">
const colorMode = useColorMode()
const { t } = useI18n()

const opciones = computed(() => [
  { value: 'light', label: t('tema.claro'), icon: 'i-lucide-sun' },
  { value: 'dark', label: t('tema.oscuro'), icon: 'i-lucide-moon' },
  { value: 'system', label: t('tema.sistema'), icon: 'i-lucide-monitor' },
])

// `preference` es lo que elige la persona; `value` es lo que se acaba pintando
// cuando la preferencia es "system".
const preferencia = computed({
  get: () => colorMode.preference,
  set: (v: string) => {
    colorMode.preference = v
  },
})
</script>

<template>
  <div
    class="flex gap-0.5 rounded-lg bg-elevated/60 p-0.5"
    role="radiogroup"
    :aria-label="$t('tema.titulo')"
  >
    <button
      v-for="opcion in opciones"
      :key="opcion.value"
      type="button"
      role="radio"
      :aria-checked="preferencia === opcion.value"
      :title="opcion.label"
      class="flex flex-1 items-center justify-center gap-1.5 rounded-md px-2 py-1 text-xs transition-colors"
      :class="preferencia === opcion.value
        ? 'bg-default text-primary shadow-sm'
        : 'text-muted hover:text-default'"
      @click="preferencia = opcion.value"
    >
      <UIcon
        :name="opcion.icon"
        class="size-3.5"
      />
      <span class="hidden sm:inline">{{ opcion.label }}</span>
    </button>
  </div>
</template>
