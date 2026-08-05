<script setup lang="ts">
import type { Bloque } from '#shared/types/database'

definePageMeta({ middleware: ['empresa'] })

const { pertenencia, empresa, bloqueada } = useEmpresaActiva()
const db = useDb()
const dinero = useFormatoDinero()
const fecha = useFormatoFecha()
const { t } = useI18n()

useHead({ title: () => t('saldo.titulo') })

const { data: bloques } = await useAsyncData(
  () => `saldo:${pertenencia.value?.id}`,
  async () => {
    if (!pertenencia.value?.id) return []
    const { data } = await db
      .from('bloques')
      .select('*')
      .eq('pertenencia_id', pertenencia.value.id)
      .order('fecha', { ascending: false })
    return (data ?? []) as Bloque[]
  },
  { watch: [pertenencia] },
)

const resumen = computed(() => {
  const filas = bloques.value ?? []
  const confirmados = filas.filter(b => b.estado === 'confirmado')

  const horas = confirmados.reduce(
    (s, b) => s + horasDeBloque(b.tipo, Number(b.ajuste_horas)),
    0,
  )
  const saldo = confirmados.reduce(
    (s, b) => s + horasDeBloque(b.tipo, Number(b.ajuste_horas)) * Number(b.tarifa_hora),
    0,
  )
  const pendientes = filas.filter(b => b.estado === 'pendiente').length

  return { horas, saldo, pendientes }
})
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('saldo.titulo')"
      :subtitulo="empresa?.nombre"
    />

    <!-- Con la empresa bloqueada esta pantalla sigue viva: el saldo es dinero
         que la empresa le debe al trabajador (docs/spec/30 §3). -->
    <p
      v-if="bloqueada"
      class="rounded-xl border border-warning/40 bg-warning/10 px-4 py-3 text-sm text-warning"
    >
      {{ $t('bloqueo.soloSaldo') }}
    </p>

    <div
      v-auto-animate
      class="grid gap-3 sm:grid-cols-3"
    >
      <StatCard
        :label="$t('saldo.acumulado')"
        :value="dinero(resumen.saldo)"
        icon="i-lucide-wallet"
        tone="positive"
      />
      <StatCard
        :label="$t('saldo.horasConfirmadas')"
        :value="`${resumen.horas} ${$t('comun.horas')}`"
        icon="i-lucide-clock"
      />
      <StatCard
        :label="$t('saldo.pendienteAprobacion')"
        :value="resumen.pendientes"
        icon="i-lucide-hourglass"
        :tone="resumen.pendientes ? 'warning' : 'default'"
      />
    </div>

    <p class="text-xs text-dimmed">
      {{ $t('saldo.explicacion') }}
    </p>

    <UCard>
      <ul
        v-auto-animate
        class="divide-y divide-default/60 text-sm"
      >
        <li
          v-for="bloque in bloques"
          :key="bloque.id"
          class="flex items-center justify-between gap-4 py-2"
        >
          <div>
            <p>{{ fecha(bloque.fecha) }}</p>
            <p class="text-xs text-dimmed">
              {{ horasDeBloque(bloque.tipo, Number(bloque.ajuste_horas)) }}
              {{ $t('comun.horas') }}
            </p>
          </div>
          <div class="text-right">
            <p class="tabular-nums">
              {{ dinero(horasDeBloque(bloque.tipo, Number(bloque.ajuste_horas)) * Number(bloque.tarifa_hora)) }}
            </p>
            <UBadge
              :color="bloque.estado === 'confirmado' ? 'success' : 'warning'"
              variant="subtle"
              size="sm"
            >
              {{ bloque.estado }}
            </UBadge>
          </div>
        </li>
      </ul>

      <p
        v-if="!bloques?.length"
        class="py-8 text-center text-sm text-muted"
      >
        {{ $t('saldo.sinRegistros') }}
      </p>
    </UCard>
  </div>
</template>
