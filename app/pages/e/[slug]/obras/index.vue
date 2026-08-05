<script setup lang="ts">
import type { Cliente, Obra } from '#shared/types/database'

definePageMeta({ middleware: ['empresa'] })

const { empresa } = useEmpresaActiva()
const db = useDb()
const fecha = useFormatoFecha()
const { t } = useI18n()

useHead({ title: () => t('obra.titulo') })

const busqueda = ref('')

const { data } = await useAsyncData(
  () => `obras:${empresa.value?.id}`,
  async () => {
    if (!empresa.value?.id) return { obras: [], clientes: [] }

    const [obras, clientes] = await Promise.all([
      db.from('obras').select('*').eq('empresa_id', empresa.value.id).order('numero', { ascending: false }),
      db.from('clientes').select('*').eq('empresa_id', empresa.value.id),
    ])

    return {
      obras: (obras.data ?? []) as Obra[],
      clientes: (clientes.data ?? []) as Cliente[],
    }
  },
  { watch: [empresa] },
)

const nombreCliente = (id: string | null) =>
  data.value?.clientes.find(c => c.id === id)?.nombre ?? '—'

const filtradas = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  const obras = data.value?.obras ?? []
  if (!q) return obras
  return obras.filter(
    o => o.titulo.toLowerCase().includes(q) || String(o.numero).includes(q),
  )
})
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('obra.titulo')"
      :subtitulo="empresa?.nombre"
    >
      <template #acciones>
        <UInput
          v-model="busqueda"
          icon="i-lucide-search"
          size="sm"
          :placeholder="$t('comun.buscar')"
        />
      </template>
    </AppHeader>

    <div
      v-auto-animate
      class="grid gap-3 md:grid-cols-2 xl:grid-cols-3"
    >
      <NuxtLink
        v-for="obra in filtradas"
        :key="obra.id"
        :to="`/e/${$route.params.slug}/obras/${obra.id}`"
        class="rounded-xl border border-default p-4 transition-colors hover:border-primary/60 hover:bg-elevated/40"
      >
        <div class="flex items-start justify-between gap-2">
          <p class="font-medium">
            <span class="text-dimmed">#{{ obra.numero }}</span>
            {{ obra.titulo }}
          </p>
          <EstadoBadge
            :estado="obra.estado"
            tipo="obra"
          />
        </div>
        <p class="mt-2 text-xs text-muted">
          {{ $t('obra.cliente') }}: {{ nombreCliente(obra.cliente_id) }}
        </p>
        <p class="mt-1 text-xs text-dimmed">
          {{ fecha(obra.fecha_inicio) }} → {{ fecha(obra.fecha_fin) }}
        </p>
      </NuxtLink>
    </div>

    <p
      v-if="!filtradas.length"
      class="rounded-xl border border-dashed border-default p-10 text-center text-sm text-muted"
    >
      {{ $t('obra.sinObras') }}
    </p>
  </div>
</template>
