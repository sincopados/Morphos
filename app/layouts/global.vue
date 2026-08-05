<script setup lang="ts">
const { t } = useI18n()

const enlaces = computed(() => [
  { label: t('nav.global'), icon: 'i-lucide-globe', to: '/global' },
  { label: t('nav.empresas'), icon: 'i-lucide-building-2', to: '/global/empresas' },
  { label: t('nav.usuarios'), icon: 'i-lucide-users-round', to: '/global/usuarios' },
  { label: t('nav.egresos'), icon: 'i-lucide-receipt', to: '/global/egresos' },
  { label: t('nav.soporte'), icon: 'i-lucide-life-buoy', to: '/global/soporte' },
])
</script>

<template>
  <div class="min-h-screen bg-default text-default">
    <div class="mx-auto flex max-w-7xl gap-6 p-4 lg:p-6">
      <aside class="hidden w-56 shrink-0 flex-col gap-4 lg:flex">
        <div class="rounded-xl border border-primary/40 bg-primary/5 p-3">
          <p class="text-[0.65rem] font-medium uppercase tracking-widest text-primary">
            MORPHOS
          </p>
          <p class="mt-1 font-medium">
            {{ $t('rol.morphos_core') }}
          </p>
          <p class="mt-1 text-xs text-dimmed">
            {{ $t('global.subtitulo') }}
          </p>
        </div>

        <nav
          v-auto-animate
          class="flex flex-col gap-1"
        >
          <NuxtLink
            v-for="enlace in enlaces"
            :key="enlace.to"
            :to="enlace.to"
            class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm text-muted transition-colors hover:bg-elevated hover:text-default"
            active-class="bg-elevated font-medium !text-primary"
          >
            <UIcon
              :name="enlace.icon"
              class="size-4"
            />
            {{ enlace.label }}
          </NuxtLink>
        </nav>
      </aside>

      <main class="min-w-0 flex-1">
        <slot />
      </main>
    </div>
  </div>
</template>
