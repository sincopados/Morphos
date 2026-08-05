<script setup lang="ts">
defineProps<{ titulo: string, subtitulo?: string }>()
</script>

<template>
  <header class="flex flex-wrap items-center justify-between gap-4 border-b border-default pb-4">
    <div>
      <h1 class="text-xl font-semibold">
        {{ titulo }}
      </h1>
      <p
        v-if="subtitulo"
        class="text-sm text-muted"
      >
        {{ subtitulo }}
      </p>
    </div>

    <div class="flex items-center gap-2">
      <slot name="acciones" />
      <LocaleSwitcher />
      <UserMenu />
    </div>
  </header>
</template>
