<script setup lang="ts">
const localePath = useLocalePath()
</script>

<template>
  <div class="min-h-svh flex flex-col">
    <header class="flex items-center justify-between p-4">
      <NuxtLink :to="localePath('/')">
        <AppLogo class="w-auto h-6 shrink-0" />
      </NuxtLink>

      <div class="flex items-center gap-1">
        <LocaleToggle />
        <UColorModeButton />
      </div>
    </header>

    <main class="flex-1 flex items-center justify-center p-4">
      <div class="w-full max-w-sm">
        <slot />
      </div>
    </main>
  </div>
</template>
