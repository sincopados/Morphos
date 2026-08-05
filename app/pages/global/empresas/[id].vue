<script setup lang="ts">
import type { Empresa, Membresia, Pertenencia, Usuario } from '#shared/types/database'

definePageMeta({ layout: 'global', middleware: ['morphos-core'] })

const route = useRoute()
const db = useDb()
const dinero = useFormatoDinero()
const fecha = useFormatoFecha()

const empresaId = computed(() => String(route.params.id))
const error = ref('')
const trabajando = ref(false)

const { data, refresh } = await useAsyncData(
  () => `global:empresa:${empresaId.value}`,
  async () => {
    const [empresa, membresia, equipo] = await Promise.all([
      db.from('empresas').select('*').eq('id', empresaId.value).single(),
      db.from('membresias').select('*').eq('empresa_id', empresaId.value).maybeSingle(),
      db.from('pertenencias').select('*, usuarios(*)').eq('empresa_id', empresaId.value),
    ])

    return {
      empresa: empresa.data as Empresa | null,
      membresia: membresia.data as Membresia | null,
      equipo: (equipo.data ?? []) as unknown as (Pertenencia & { usuarios: Usuario | null })[],
    }
  },
)

useHead({ title: () => data.value?.empresa?.nombre ?? '' })

/**
 * Registrar el pago extiende el ciclo y desbloquea en el mismo paso: prepago,
 * sin mora ni pasos manuales (supabase/migrations/0002_bloqueo.sql).
 */
async function registrarPago() {
  if (!data.value?.membresia) return
  trabajando.value = true
  error.value = ''

  const { error: err } = await db.rpc('registrar_pago_membresia', {
    p_empresa: empresaId.value,
    p_importe: Number(data.value.membresia.importe),
    p_metodo: 'manual',
  } as never)

  trabajando.value = false
  if (err) {
    error.value = err.message
    return
  }
  await refresh()
}

async function darDeBaja() {
  trabajando.value = true
  error.value = ''

  const { error: err } = await db
    .from('empresas')
    .update({ estado: 'dada_de_baja', dada_de_baja_en: new Date().toISOString() })
    .eq('id', empresaId.value)

  trabajando.value = false
  if (err) {
    error.value = err.message
    return
  }
  await refresh()
}

async function alternarSupervision() {
  if (!data.value?.empresa) return
  await db
    .from('empresas')
    .update({ supervision_contratada: !data.value.empresa.supervision_contratada })
    .eq('id', empresaId.value)
  await refresh()
}
</script>

<template>
  <div
    v-if="data?.empresa"
    class="flex flex-col gap-6"
  >
    <AppHeader
      :titulo="data.empresa.nombre"
      :subtitulo="`${data.empresa.jurisdiccion} · ${data.empresa.zona_horaria}`"
    >
      <template #acciones>
        <EstadoBadge :estado="data.empresa.estado" />
      </template>
    </AppHeader>

    <div v-auto-animate>
      <p
        v-if="error"
        class="rounded-lg bg-error/10 px-3 py-2 text-sm text-error"
      >
        {{ error }}
      </p>
    </div>

    <div
      v-auto-animate
      class="grid gap-3 sm:grid-cols-3"
    >
      <StatCard
        :label="$t('empresas.vence')"
        :value="fecha(data.membresia?.vence_el ?? null)"
        icon="i-lucide-calendar-clock"
        :tone="data.empresa.estado === 'bloqueada' ? 'negative' : 'default'"
      />
      <StatCard
        :label="$t('egresos.importe')"
        :value="dinero(Number(data.membresia?.importe ?? 0), data.membresia?.moneda ?? 'EUR')"
        icon="i-lucide-credit-card"
      />
      <StatCard
        :label="$t('empresas.equipo')"
        :value="data.equipo.length"
        icon="i-lucide-users"
      />
    </div>

    <div class="flex flex-wrap gap-2">
      <UButton
        icon="i-lucide-check"
        :loading="trabajando"
        :disabled="!data.membresia || data.empresa.estado === 'dada_de_baja'"
        :label="$t('empresas.registrarPago')"
        @click="registrarPago"
      />
      <UButton
        color="neutral"
        variant="subtle"
        icon="i-lucide-shield-check"
        :label="`${$t('empresas.supervision')}: ${data.empresa.supervision_contratada ? '✓' : '—'}`"
        @click="alternarSupervision"
      />
      <UButton
        color="error"
        variant="subtle"
        icon="i-lucide-user-minus"
        :disabled="data.empresa.estado === 'dada_de_baja'"
        :label="$t('empresas.darDeBaja')"
        @click="darDeBaja"
      />
    </div>

    <p class="text-xs text-dimmed">
      {{ $t('global.sinMora') }}
    </p>

    <UCard>
      <template #header>
        <h2 class="font-medium">
          {{ $t('empresas.equipo') }}
        </h2>
      </template>

      <ul
        v-auto-animate
        class="divide-y divide-default/60 text-sm"
      >
        <li
          v-for="p in data.equipo"
          :key="p.id"
          class="flex items-center justify-between gap-3 py-2"
        >
          <div>
            <p>{{ p.usuarios?.nombre }}</p>
            <p class="text-xs text-dimmed">
              {{ p.usuarios?.email }}
            </p>
          </div>
          <div class="flex items-center gap-2">
            <UBadge
              color="neutral"
              variant="subtle"
              size="sm"
            >
              {{ $t(`rol.${p.rol}`) }}
            </UBadge>
            <span class="text-xs tabular-nums text-dimmed">
              {{ dinero(Number(p.tarifa_hora)) }}
            </span>
          </div>
        </li>
      </ul>
    </UCard>
  </div>
</template>
