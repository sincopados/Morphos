<script setup lang="ts">
const { slug, empresa, rol } = useEmpresaActiva()
const gestiona = useGestionaEmpresa()
const esCore = useEsMorphosCore()
const { t } = useI18n()

const enlaces = computed(() => {
  if (!slug.value) return []
  const base = `/e/${slug.value}`

  const items = [
    { label: t('nav.dashboard'), icon: 'i-lucide-layout-dashboard', to: base, visible: gestiona.value },
    { label: t('nav.obras'), icon: 'i-lucide-hammer', to: `${base}/obras`, visible: gestiona.value },
    { label: t('nav.equipo'), icon: 'i-lucide-users', to: `${base}/equipo`, visible: rol.value === 'owner' || esCore.value },
    { label: t('nav.miSaldo'), icon: 'i-lucide-wallet', to: `${base}/saldo`, visible: !gestiona.value },
    { label: t('nav.soporte'), icon: 'i-lucide-life-buoy', to: `${base}/soporte`, visible: true },
  ]

  return items.filter(i => i.visible)
})
</script>

<template>
  <div class="min-h-screen bg-default text-default">
    <div class="mx-auto flex max-w-7xl gap-6 p-4 lg:p-6">
      <aside
        v-if="empresa"
        class="hidden w-56 shrink-0 flex-col gap-4 lg:flex"
      >
        <!-- morphos_core llega desde el Dashboard Global, no desde el selector -->
        <NuxtLink
          :to="esCore ? '/global/empresas' : '/empresas'"
          class="group rounded-xl border border-default p-3 transition-colors hover:border-primary/50"
          :class="esCore ? 'border-primary/40 bg-primary/5' : ''"
        >
          <p class="text-[0.65rem] font-medium uppercase tracking-widest text-primary">
            {{ esCore ? $t('rol.morphos_core') : 'MORPHOS' }}
          </p>
          <p class="mt-1 truncate font-medium">
            {{ empresa.nombre }}
          </p>
          <p class="mt-1 flex items-center gap-1 text-xs text-dimmed">
            <UIcon
              :name="esCore ? 'i-lucide-arrow-left' : 'i-lucide-repeat'"
              class="size-3"
            />
            {{ esCore ? $t('empresas.titulo') : $t('nav.cambiarEmpresa') }}
          </p>
        </NuxtLink>

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

        <UBadge
          v-if="rol"
          color="neutral"
          variant="subtle"
          class="self-start"
        >
          {{ $t(`rol.${rol}`) }}
        </UBadge>
      </aside>

      <main class="min-w-0 flex-1">
        <slot />
      </main>
    </div>
  </div>
</template>
