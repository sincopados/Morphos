<script setup lang="ts">
import type { DropdownMenuItem } from '@nuxt/ui'

const usuario = useMorphosUser()
const esCore = useEsMorphosCore()
const { rol } = useEmpresaActiva()
const supabase = useSupabaseClient()
const { t } = useI18n()

const iniciales = computed(() => {
  const nombre = usuario.value?.nombre?.trim()
  if (!nombre) return '?'
  return nombre
    .split(/\s+/)
    .slice(0, 2)
    .map(parte => parte[0]?.toUpperCase() ?? '')
    .join('')
})

// El rol que se muestra: el global si es del equipo interno, si no el de la
// empresa que tenga seleccionada.
const etiquetaRol = computed(() => {
  if (esCore.value) return t('rol.morphos_core')
  return rol.value ? t(`rol.${rol.value}`) : ''
})

async function salir() {
  await supabase.auth.signOut()
  useMorphosUser().value = null
  usePertenencias().value = []
  await navigateTo('/login')
}

const items = computed<DropdownMenuItem[][]>(() => [
  [{
    type: 'label',
    label: usuario.value?.nombre ?? '',
    description: usuario.value?.email,
  }],
  [{
    label: t('perfil.titulo'),
    icon: 'i-lucide-user-round',
    to: '/perfil',
  }],
  [{
    label: t('tema.titulo'),
    icon: 'i-lucide-palette',
    slot: 'tema',
    type: 'label',
  }],
  [{
    label: t('nav.salir'),
    icon: 'i-lucide-log-out',
    color: 'error',
    onSelect: () => {
      salir()
    },
  }],
])
</script>

<template>
  <UDropdownMenu
    :items="items"
    :ui="{ content: 'w-60' }"
  >
    <UButton
      color="neutral"
      variant="ghost"
      size="sm"
      class="gap-2"
      :aria-label="$t('perfil.titulo')"
    >
      <span
        class="flex size-7 items-center justify-center rounded-full bg-primary/15 text-xs font-medium text-primary"
      >
        {{ iniciales }}
      </span>
      <span class="hidden text-left sm:block">
        <span class="block text-sm leading-tight">{{ usuario?.nombre }}</span>
        <span class="block text-[0.65rem] leading-tight text-dimmed">{{ etiquetaRol }}</span>
      </span>
      <UIcon
        name="i-lucide-chevron-down"
        class="size-3.5 text-dimmed"
      />
    </UButton>

    <template #tema>
      <div class="w-full px-1 py-1">
        <p class="mb-1 text-[0.65rem] uppercase tracking-wide text-dimmed">
          {{ $t('tema.titulo') }}
        </p>
        <ThemeSwitcher />
      </div>
    </template>
  </UDropdownMenu>
</template>
