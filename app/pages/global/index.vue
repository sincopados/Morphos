<script setup lang="ts">
import type {
  EgresoMorphos,
  Empresa,
  Incidencia,
  Membresia,
  PagoMembresia,
} from '#shared/types/database'

definePageMeta({ layout: 'global', middleware: ['morphos-core'] })

const db = useDb()
const dinero = useFormatoDinero()
const fechaFmt = useFormatoFecha()
const { t } = useI18n()

useHead({ title: () => t('global.titulo') })

const mes = computed(() => {
  const hoy = new Date()
  const inicio = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  const previo = new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1)
  const fin = new Date(hoy.getFullYear(), hoy.getMonth() + 1, 1)
  return { inicio: isoDate(inicio), previo: isoDate(previo), fin: isoDate(fin) }
})

const { data } = await useAsyncData('global:resumen', async () => {
  const hoy = isoDate(new Date())
  const enSieteDias = isoDate(new Date(Date.now() + 7 * 864e5))

  const [empresas, membresias, pagos, egresos, incidencias, personas, obras] = await Promise.all([
    db.from('empresas').select('*'),
    db.from('membresias').select('*'),
    // Devengo: el recaudo pertenece al ciclo que cubre, no a la fecha de cobro.
    db.from('pagos_membresia').select('*').gte('ciclo', mes.value.previo).lt('ciclo', mes.value.fin),
    db.from('egresos_morphos').select('*').gte('fecha', mes.value.previo).lt('fecha', mes.value.fin),
    db.from('incidencias').select('*').neq('estado', 'cerrada').order('created_at'),
    db.from('pertenencias').select('usuario_id').eq('activa', true),
    db.from('obras').select('id').eq('estado', 'activa'),
  ])

  return {
    empresas: (empresas.data ?? []) as Empresa[],
    membresias: (membresias.data ?? []) as Membresia[],
    pagos: (pagos.data ?? []) as PagoMembresia[],
    egresos: (egresos.data ?? []) as EgresoMorphos[],
    incidencias: (incidencias.data ?? []) as Incidencia[],
    personas: new Set((personas.data ?? []).map(p => p.usuario_id)).size,
    obrasActivas: (obras.data ?? []).length,
    hoy,
    enSieteDias,
  }
})

/**
 * Tres estados, no dos: `bloqueada` es recuperable y es el embudo de cobro;
 * `dada_de_baja` es churn y sale de los contadores (docs/spec/30 §2).
 */
const empresasPorEstado = computed(() => {
  const lista = data.value?.empresas ?? []
  return {
    activas: lista.filter(e => e.estado === 'activa').length,
    bloqueadas: lista.filter(e => e.estado === 'bloqueada').length,
    baja: lista.filter(e => e.estado === 'dada_de_baja').length,
    supervision: lista.filter(e => e.supervision_contratada).length,
  }
})

const nombreEmpresa = (id: string) =>
  data.value?.empresas.find(e => e.id === id)?.nombre ?? '—'

/** Ventana de aviso: 7 días naturales antes del vencimiento (ADR-0001). */
const proximasAVencer = computed(() => {
  const d = data.value
  if (!d) return []

  return d.membresias
    .filter((m) => {
      const empresa = d.empresas.find(e => e.id === m.empresa_id)
      return empresa?.estado === 'activa'
        && m.vence_el >= d.hoy
        && m.vence_el <= d.enSieteDias
    })
    .map(m => ({
      ...m,
      nombre: nombreEmpresa(m.empresa_id),
      dias: Math.ceil((new Date(m.vence_el).getTime() - Date.now()) / 864e5),
    }))
    .sort((a, b) => a.dias - b.dias)
})

const recaudo = computed(() => {
  const d = data.value
  if (!d) return { pagas: 0, importePagas: 0, proximas: 0, ingresos: 0, egresos: 0, neto: 0, delta: null as number | null }

  const delMes = d.pagos.filter(p => p.ciclo >= mes.value.inicio && !p.fallido)
  const delPrevio = d.pagos.filter(p => p.ciclo < mes.value.inicio && !p.fallido)

  const ingresos = delMes.reduce((s, p) => s + Number(p.importe), 0)
  const ingresosPrevio = delPrevio.reduce((s, p) => s + Number(p.importe), 0)
  const egresos = d.egresos
    .filter(e => e.fecha >= mes.value.inicio)
    .reduce((s, e) => s + Number(e.importe), 0)

  return {
    pagas: delMes.length,
    importePagas: ingresos,
    proximas: proximasAVencer.value.reduce((s, m) => s + Number(m.importe), 0),
    ingresos,
    egresos,
    neto: ingresos - egresos,
    delta: ingresosPrevio === 0 ? null : ((ingresos - ingresosPrevio) / ingresosPrevio) * 100,
  }
})

const bloqueadas = computed(() =>
  (data.value?.empresas ?? []).filter(e => e.estado === 'bloqueada'),
)
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('global.titulo')"
      :subtitulo="$t('global.subtitulo')"
    />

    <div
      v-auto-animate
      class="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
    >
      <StatCard
        :label="$t('global.empresasActivas')"
        :value="empresasPorEstado.activas"
        icon="i-lucide-building-2"
        tone="positive"
      />
      <StatCard
        :label="$t('global.empresasBloqueadas')"
        :value="empresasPorEstado.bloqueadas"
        icon="i-lucide-lock"
        :tone="empresasPorEstado.bloqueadas ? 'negative' : 'default'"
      />
      <StatCard
        :label="$t('global.dadasDeBaja')"
        :value="empresasPorEstado.baja"
        icon="i-lucide-user-minus"
        :hint="$t('empresa.estado.dada_de_baja')"
      />
      <StatCard
        :label="$t('global.supervisionContratada')"
        :value="empresasPorEstado.supervision"
        icon="i-lucide-shield-check"
      />
    </div>

    <div class="grid gap-6 lg:grid-cols-2">
      <UCard>
        <template #header>
          <div>
            <h2 class="font-medium">
              {{ $t('global.recaudoMembresias') }}
            </h2>
            <p class="mt-1 text-xs text-dimmed">
              {{ $t('global.sinMora') }}
            </p>
          </div>
        </template>

        <div
          v-auto-animate
          class="grid gap-3 sm:grid-cols-2"
        >
          <StatCard
            :label="$t('global.pagas')"
            :value="dinero(recaudo.importePagas)"
            :hint="`${recaudo.pagas}`"
            tone="positive"
          />
          <StatCard
            :label="$t('global.proximasAVencer')"
            :value="dinero(recaudo.proximas)"
            :hint="`${proximasAVencer.length}`"
            tone="warning"
          />
        </div>

        <ul
          v-auto-animate
          class="mt-4 divide-y divide-default/60 text-sm"
        >
          <li
            v-for="m in proximasAVencer"
            :key="m.id"
            class="flex items-center justify-between gap-3 py-2"
          >
            <span>{{ m.nombre }}</span>
            <span class="text-xs text-warning">
              {{ $t('global.venceEnDias', { dias: m.dias }) }} · {{ fechaFmt(m.vence_el) }}
            </span>
          </li>
        </ul>
      </UCard>

      <UCard>
        <template #header>
          <h2 class="font-medium">
            {{ $t('global.recaudoMensual') }}
          </h2>
        </template>

        <div
          v-auto-animate
          class="grid gap-3 sm:grid-cols-3"
        >
          <StatCard
            :label="$t('global.ingresos')"
            :value="dinero(recaudo.ingresos)"
            :delta="recaudo.delta"
            :hint="$t('global.vsMesAnterior')"
            tone="positive"
          />
          <StatCard
            :label="$t('global.egresos')"
            :value="dinero(recaudo.egresos)"
            tone="negative"
          />
          <StatCard
            :label="$t('global.neto')"
            :value="dinero(recaudo.neto)"
            :tone="recaudo.neto >= 0 ? 'positive' : 'negative'"
          />
        </div>
      </UCard>
    </div>

    <div class="grid gap-6 lg:grid-cols-2">
      <UCard>
        <template #header>
          <h2 class="font-medium">
            {{ $t('global.alertasSoporte') }}
          </h2>
        </template>

        <ul
          v-auto-animate
          class="divide-y divide-default/60 text-sm"
        >
          <li
            v-for="inc in data?.incidencias ?? []"
            :key="inc.id"
            class="flex items-center justify-between gap-3 py-2"
          >
            <div>
              <p>{{ inc.asunto }}</p>
              <p class="text-xs text-dimmed">
                {{ nombreEmpresa(inc.empresa_id) }} · {{ fechaFmt(inc.created_at) }}
              </p>
            </div>
            <UBadge
              :color="inc.prioridad === 'alta' ? 'error' : 'neutral'"
              variant="subtle"
              size="sm"
            >
              {{ $t(`soporte.prio.${inc.prioridad}`) }}
            </UBadge>
          </li>
        </ul>

        <p
          v-if="!data?.incidencias?.length"
          class="py-6 text-center text-sm text-muted"
        >
          {{ $t('global.sinAlertas') }}
        </p>
      </UCard>

      <UCard>
        <template #header>
          <h2 class="font-medium">
            {{ $t('global.alertasCobro') }}
          </h2>
        </template>

        <ul
          v-auto-animate
          class="divide-y divide-default/60 text-sm"
        >
          <li
            v-for="e in bloqueadas"
            :key="e.id"
            class="flex items-center justify-between gap-3 py-2"
          >
            <span>{{ e.nombre }}</span>
            <UButton
              size="xs"
              variant="subtle"
              :to="`/global/empresas/${e.id}`"
              :label="$t('empresas.registrarPago')"
            />
          </li>
          <li
            v-for="m in proximasAVencer"
            :key="m.id"
            class="flex items-center justify-between gap-3 py-2"
          >
            <span>{{ m.nombre }}</span>
            <span class="text-xs text-warning">
              {{ $t('global.venceEnDias', { dias: m.dias }) }}
            </span>
          </li>
        </ul>

        <p
          v-if="!bloqueadas.length && !proximasAVencer.length"
          class="py-6 text-center text-sm text-muted"
        >
          {{ $t('global.sinAlertas') }}
        </p>
      </UCard>
    </div>

    <UCard>
      <template #header>
        <h2 class="font-medium">
          {{ $t('global.resumen') }}
        </h2>
      </template>

      <div
        v-auto-animate
        class="grid gap-3 sm:grid-cols-3"
      >
        <StatCard
          :label="$t('global.personasActivas')"
          :value="data?.personas ?? 0"
          icon="i-lucide-users"
        />
        <StatCard
          :label="$t('global.obrasActivas')"
          :value="data?.obrasActivas ?? 0"
          icon="i-lucide-hammer"
        />
        <StatCard
          :label="$t('global.supervisionContratada')"
          :value="empresasPorEstado.supervision"
          icon="i-lucide-shield-check"
        />
      </div>
    </UCard>
  </div>
</template>
