<script setup lang="ts">
const localePath = useLocalePath()
</script>

<template>
  <div class="min-h-svh flex flex-col">
    <header class="flex items-center justify-end gap-1 p-4">
      <LocaleToggle />
      <UColorModeButton />
    </header>

    <main class="flex-1 flex items-center justify-center p-4 pb-16">
      <div class="w-full max-w-sm space-y-8">
        <div class="flex flex-col items-center gap-2">
          <NuxtLink :to="localePath('/')">
            <AppLogo class="w-auto h-7 shrink-0" />
          </NuxtLink>
          <p class="text-sm text-muted">
            {{ $t('app.tagline') }}
          </p>
        </div>

        <slot />
      </div>
    </main>
  </div>
</template>
