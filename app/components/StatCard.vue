<script setup lang="ts">
defineProps<{
  label: string
  value: string | number
  hint?: string
  icon?: string
  /** Variación porcentual contra el período anterior. */
  delta?: number | null
  tone?: 'default' | 'positive' | 'negative' | 'warning'
}>()
</script>

<template>
  <div
    class="rounded-xl border border-default bg-elevated/40 p-4 transition-colors hover:border-primary/40"
  >
    <div class="flex items-start justify-between gap-3">
      <p class="text-sm text-muted">
        {{ label }}
      </p>
      <UIcon
        v-if="icon"
        :name="icon"
        class="size-5 shrink-0 text-primary"
      />
    </div>

    <p
      class="mt-2 text-2xl font-semibold tabular-nums"
      :class="{
        'text-success': tone === 'positive',
        'text-error': tone === 'negative',
        'text-warning': tone === 'warning',
      }"
    >
      {{ value }}
    </p>

    <p
      v-if="delta !== null && delta !== undefined"
      class="mt-1 text-xs tabular-nums"
      :class="delta >= 0 ? 'text-success' : 'text-error'"
    >
      {{ delta >= 0 ? '▲' : '▼' }} {{ Math.abs(delta).toFixed(1) }}%
      <span class="text-dimmed">{{ hint }}</span>
    </p>
    <p
      v-else-if="hint"
      class="mt-1 text-xs text-dimmed"
    >
      {{ hint }}
    </p>
  </div>
</template>
