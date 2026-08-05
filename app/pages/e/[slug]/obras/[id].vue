<script setup lang="ts">
import type {
  Bloque,
  Cobro,
  Obra,
  ObraGasto,
  ObraLinea,
  ObraTarea,
} from '#shared/types/database'

definePageMeta({ middleware: ['empresa'] })

const route = useRoute()
const db = useDb()
const dinero = useFormatoDinero()
const fecha = useFormatoFecha()

const obraId = computed(() => String(route.params.id))

const { data } = await useAsyncData(
  () => `obra:${obraId.value}`,
  async () => {
    const [obra, lineas, gastos, bloques, tareas, cobros] = await Promise.all([
      db.from('obras').select('*').eq('id', obraId.value).single(),
      db.from('obra_lineas').select('*').eq('obra_id', obraId.value).order('orden'),
      db.from('obra_gastos').select('*').eq('obra_id', obraId.value),
      db.from('bloques').select('*').eq('obra_id', obraId.value).order('fecha', { ascending: false }),
      db.from('obra_tareas').select('*').eq('obra_id', obraId.value),
      db.from('cobros').select('*').eq('obra_id', obraId.value),
    ])

    return {
      obra: obra.data as Obra | null,
      lineas: (lineas.data ?? []) as ObraLinea[],
      gastos: (gastos.data ?? []) as ObraGasto[],
      bloques: (bloques.data ?? []) as Bloque[],
      tareas: (tareas.data ?? []) as ObraTarea[],
      cobros: (cobros.data ?? []) as Cobro[],
    }
  },
)

useHead({ title: () => data.value?.obra?.titulo ?? '' })

/** Panel económico: todo derivado, nunca almacenado (docs/spec/50 §8). */
const panel = computed(() => {
  const d = data.value
  if (!d) return { ingresos: 0, manoObra: 0, gastos: 0, coste: 0, beneficio: 0, porcentaje: 0 }

  const ingresos = d.lineas.reduce(
    (s, l) => s + Number(l.cantidad) * Number(l.precio_unitario),
    0,
  )
  const manoObra = d.bloques
    .filter(b => b.estado === 'confirmado')
    .reduce(
      (s, b) => s + horasDeBloque(b.tipo, Number(b.ajuste_horas)) * Number(b.tarifa_hora),
      0,
    )
  const gastos = d.gastos
    .filter(g => g.estado === 'confirmado')
    .reduce((s, g) => s + Number(g.importe), 0)

  const coste = manoObra + gastos
  const beneficio = ingresos - coste

  return {
    ingresos,
    manoObra,
    gastos,
    coste,
    beneficio,
    porcentaje: ingresos ? (beneficio / ingresos) * 100 : 0,
  }
})

const horasTotales = computed(() =>
  (data.value?.bloques ?? [])
    .filter(b => b.estado === 'confirmado')
    .reduce((s, b) => s + horasDeBloque(b.tipo, Number(b.ajuste_horas)), 0),
)
</script>

<template>
  <div
    v-if="data?.obra"
    class="flex flex-col gap-6"
  >
    <AppHeader
      :titulo="`#${data.obra.numero} · ${data.obra.titulo}`"
      :subtitulo="data.obra.direccion_obra ?? undefined"
    >
      <template #acciones>
        <EstadoBadge
          :estado="data.obra.estado"
          tipo="obra"
        />
      </template>
    </AppHeader>

    <div
      v-auto-animate
      class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
    >
      <StatCard
        :label="$t('obra.ingresos')"
        :value="dinero(panel.ingresos)"
        icon="i-lucide-banknote"
      />
      <StatCard
        :label="$t('obra.manoObra')"
        :value="dinero(panel.manoObra)"
        :hint="`${horasTotales} ${$t('comun.horas')}`"
        icon="i-lucide-clock"
      />
      <StatCard
        :label="$t('obra.gastos')"
        :value="dinero(panel.gastos)"
        icon="i-lucide-receipt"
      />
      <StatCard
        :label="$t('obra.beneficio')"
        :value="dinero(panel.beneficio)"
        :hint="`${panel.porcentaje.toFixed(1)}%`"
        :tone="panel.beneficio >= 0 ? 'positive' : 'negative'"
        icon="i-lucide-scale"
      />
    </div>

    <div class="grid gap-6 lg:grid-cols-2">
      <UCard>
        <template #header>
          <h2 class="font-medium">
            {{ $t('obra.lineas') }}
          </h2>
        </template>

        <ul
          v-auto-animate
          class="divide-y divide-default/60 text-sm"
        >
          <li
            v-for="linea in data.lineas"
            :key="linea.id"
            class="flex items-start justify-between gap-4 py-2"
          >
            <div>
              <p class="font-medium">
                {{ linea.nombre }}
              </p>
              <p
                v-if="linea.descripcion"
                class="text-xs text-dimmed"
              >
                {{ linea.descripcion }}
              </p>
            </div>
            <p class="shrink-0 tabular-nums">
              {{ dinero(Number(linea.cantidad) * Number(linea.precio_unitario)) }}
            </p>
          </li>
        </ul>
      </UCard>

      <UCard>
        <template #header>
          <div>
            <h2 class="font-medium">
              {{ $t('obra.manoObra') }}
            </h2>
            <p class="mt-1 text-xs text-dimmed">
              {{ $t('obra.manoObraDerivada') }}
            </p>
          </div>
        </template>

        <ul
          v-auto-animate
          class="divide-y divide-default/60 text-sm"
        >
          <li
            v-for="bloque in data.bloques"
            :key="bloque.id"
            class="flex items-center justify-between gap-4 py-2"
          >
            <div>
              <p>{{ fecha(bloque.fecha) }}</p>
              <p class="text-xs text-dimmed">
                {{ horasDeBloque(bloque.tipo, Number(bloque.ajuste_horas)) }}
                {{ $t('comun.horas') }}
                <span
                  v-if="bloque.estado === 'pendiente'"
                  class="ml-1 text-warning"
                >
                  · {{ $t('saldo.pendienteAprobacion') }}
                </span>
              </p>
            </div>
            <p class="tabular-nums">
              {{ dinero(horasDeBloque(bloque.tipo, Number(bloque.ajuste_horas)) * Number(bloque.tarifa_hora)) }}
            </p>
          </li>
        </ul>
      </UCard>
    </div>

    <UCard v-if="data.tareas.length">
      <template #header>
        <h2 class="font-medium">
          {{ $t('dashboard.tareasPendientes') }}
        </h2>
      </template>

      <ul
        v-auto-animate
        class="divide-y divide-default/60 text-sm"
      >
        <li
          v-for="tarea in data.tareas"
          :key="tarea.id"
          class="flex items-center justify-between gap-4 py-2"
        >
          <span :class="{ 'line-through text-dimmed': tarea.estado === 'completada' }">
            {{ tarea.titulo }}
          </span>
          <span class="text-xs text-dimmed">{{ fecha(tarea.fecha_limite) }}</span>
        </li>
      </ul>
    </UCard>
  </div>
</template>
