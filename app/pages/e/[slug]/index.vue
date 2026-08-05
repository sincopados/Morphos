<script setup lang="ts">
import type { Bloque, Cobro, Obra, ObraGasto, ObraTarea } from '#shared/types/database'

definePageMeta({ middleware: ['empresa'] })

const { empresa } = useEmpresaActiva()
const gestiona = useGestionaEmpresa()
const db = useDb()
const dinero = useFormatoDinero()
const { t } = useI18n()

if (!gestiona.value) {
  await navigateTo(`/e/${useRoute().params.slug}/saldo`)
}

useHead({ title: () => t('dashboard.titulo') })

const periodo = ref<'semana' | 'mes'>('semana')

const rango = computed(() => {
  const hoy = new Date()
  if (periodo.value === 'mes') {
    const inicio = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
    const fin = new Date(hoy.getFullYear(), hoy.getMonth() + 1, 1)
    return { desde: isoDate(inicio), hasta: isoDate(fin) }
  }
  const { inicio, fin } = semanaEnCurso(hoy)
  return { desde: isoDate(inicio), hasta: isoDate(fin) }
})

const semana = computed(() => {
  const { inicio, fin } = semanaEnCurso()
  const anterior = new Date(inicio)
  anterior.setDate(anterior.getDate() - 7)
  return {
    desde: isoDate(inicio),
    hasta: isoDate(fin),
    previaDesde: isoDate(anterior),
  }
})

const { data, pending } = await useAsyncData(
  () => `dashboard:${empresa.value?.id}:${periodo.value}`,
  async () => {
    const empresaId = empresa.value?.id
    if (!empresaId) return null

    const { data: obras } = await db
      .from('obras')
      .select('*')
      .eq('empresa_id', empresaId)

    const lista = (obras ?? []) as Obra[]
    const ids = lista.map(o => o.id)
    if (!ids.length) {
      return { obras: lista, cobros: [], gastos: [], bloques: [], tareas: [], cobrosSemana: [] }
    }

    const [cobros, gastos, bloques, tareas, cobrosSemana] = await Promise.all([
      db.from('cobros').select('*').in('obra_id', ids)
        .eq('estado', 'confirmado')
        .gte('fecha', rango.value.desde).lt('fecha', rango.value.hasta),
      db.from('obra_gastos').select('*').in('obra_id', ids)
        .eq('estado', 'confirmado')
        .gte('fecha', rango.value.desde).lt('fecha', rango.value.hasta),
      db.from('bloques').select('*').in('obra_id', ids)
        .eq('estado', 'confirmado')
        .gte('fecha', rango.value.desde).lt('fecha', rango.value.hasta),
      db.from('obra_tareas').select('*').in('obra_id', ids)
        .neq('estado', 'completada'),
      // "Generado en la semana" es siempre semanal, sin importar el selector.
      db.from('cobros').select('*').in('obra_id', ids)
        .eq('estado', 'confirmado')
        .gte('fecha', semana.value.previaDesde).lt('fecha', semana.value.hasta),
    ])

    return {
      obras: lista,
      cobros: (cobros.data ?? []) as Cobro[],
      gastos: (gastos.data ?? []) as ObraGasto[],
      bloques: (bloques.data ?? []) as Bloque[],
      tareas: (tareas.data ?? []) as ObraTarea[],
      cobrosSemana: (cobrosSemana.data ?? []) as Cobro[],
    }
  },
  { watch: [periodo, empresa] },
)

/** Gastos por obra = mano de obra derivada del check-in + gastos confirmados. */
const porObra = computed(() => {
  if (!data.value) return []

  return data.value.obras
    .filter(o => o.estado === 'activa' || o.estado === 'atrasada')
    .map((obra) => {
      const cobros = data.value!.cobros
        .filter(c => c.obra_id === obra.id)
        .reduce((suma, c) => suma + Number(c.importe), 0)

      const manoObra = data.value!.bloques
        .filter(b => b.obra_id === obra.id)
        .reduce(
          (suma, b) => suma + horasDeBloque(b.tipo, Number(b.ajuste_horas)) * Number(b.tarifa_hora),
          0,
        )

      const gastos = data.value!.gastos
        .filter(g => g.obra_id === obra.id)
        .reduce((suma, g) => suma + Number(g.importe), 0)

      const tareas = data.value!.tareas.filter(t => t.obra_id === obra.id)
      const hoy = isoDate(new Date())

      return {
        obra,
        cobros,
        gastos: manoObra + gastos,
        margen: cobros - (manoObra + gastos),
        tareasAbiertas: tareas.length,
        tareasVencidas: tareas.filter(t => t.fecha_limite && t.fecha_limite < hoy).length,
      }
    })
    .sort((a, b) => b.cobros - a.cobros)
})

const totales = computed(() => {
  const cobros = porObra.value.reduce((s, f) => s + f.cobros, 0)
  const gastos = porObra.value.reduce((s, f) => s + f.gastos, 0)
  return { cobros, gastos, margen: cobros - gastos }
})

const generadoSemana = computed(() => {
  const filas = data.value?.cobrosSemana ?? []
  const actual = filas
    .filter(c => c.fecha >= semana.value.desde)
    .reduce((s, c) => s + Number(c.importe), 0)
  const previa = filas
    .filter(c => c.fecha < semana.value.desde)
    .reduce((s, c) => s + Number(c.importe), 0)

  return {
    actual,
    delta: previa === 0 ? null : ((actual - previa) / previa) * 100,
  }
})

const opcionesPeriodo = computed(() => [
  { label: t('dashboard.semana'), value: 'semana' as const },
  { label: t('dashboard.mes'), value: 'mes' as const },
])
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('dashboard.titulo')"
      :subtitulo="empresa?.nombre"
    >
      <template #acciones>
        <USelect
          v-model="periodo"
          :items="opcionesPeriodo"
          value-key="value"
          size="sm"
          icon="i-lucide-calendar-range"
        />
      </template>
    </AppHeader>

    <div
      v-auto-animate
      class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
    >
      <StatCard
        :label="$t('dashboard.generadoSemana')"
        :value="dinero(generadoSemana.actual)"
        :delta="generadoSemana.delta"
        :hint="$t('dashboard.vsSemanaAnterior')"
        icon="i-lucide-trending-up"
      />
      <StatCard
        :label="$t('dashboard.cobrosGenerales')"
        :value="dinero(totales.cobros)"
        icon="i-lucide-banknote"
        tone="positive"
      />
      <StatCard
        :label="$t('dashboard.gastosGenerales')"
        :value="dinero(totales.gastos)"
        icon="i-lucide-receipt"
        tone="negative"
      />
      <StatCard
        :label="$t('dashboard.margen')"
        :value="dinero(totales.margen)"
        :tone="totales.margen >= 0 ? 'positive' : 'negative'"
        icon="i-lucide-scale"
      />
    </div>

    <UCard>
      <template #header>
        <div class="flex items-center justify-between gap-2">
          <h2 class="font-medium">
            {{ $t('dashboard.cobrosPorObra') }} · {{ $t('dashboard.gastosPorObra') }}
          </h2>
          <p class="text-xs text-dimmed">
            {{ $t('dashboard.soloConfirmados') }}
          </p>
        </div>
      </template>

      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="text-left text-xs uppercase tracking-wide text-dimmed">
            <tr>
              <th class="pb-2 font-medium">
                {{ $t('obra.titulo') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('dashboard.cobrosGenerales') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('dashboard.gastosGenerales') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('dashboard.margen') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('dashboard.tareasPendientes') }}
              </th>
            </tr>
          </thead>
          <tbody v-auto-animate>
            <tr
              v-for="fila in porObra"
              :key="fila.obra.id"
              class="border-t border-default/60"
            >
              <td class="py-2">
                <NuxtLink
                  :to="`/e/${$route.params.slug}/obras/${fila.obra.id}`"
                  class="hover:text-primary"
                >
                  <span class="text-dimmed">#{{ fila.obra.numero }}</span>
                  {{ fila.obra.titulo }}
                </NuxtLink>
              </td>
              <td class="py-2 text-right tabular-nums">
                {{ dinero(fila.cobros) }}
              </td>
              <td class="py-2 text-right tabular-nums">
                {{ dinero(fila.gastos) }}
              </td>
              <td
                class="py-2 text-right tabular-nums"
                :class="fila.margen >= 0 ? 'text-success' : 'text-error'"
              >
                {{ dinero(fila.margen) }}
              </td>
              <td class="py-2 text-right tabular-nums">
                {{ fila.tareasAbiertas }}
                <span
                  v-if="fila.tareasVencidas"
                  class="ml-1 text-warning"
                >
                  ({{ fila.tareasVencidas }} {{ $t('obra.vencidas') }})
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <p
        v-if="!pending && !porObra.length"
        class="py-8 text-center text-sm text-muted"
      >
        {{ $t('dashboard.sinDatos') }}
      </p>
    </UCard>
  </div>
</template>
