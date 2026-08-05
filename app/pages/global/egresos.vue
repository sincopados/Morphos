<script setup lang="ts">
import type { EgresoCategoria, EgresoMorphos } from '#shared/types/database'

definePageMeta({ layout: 'global', middleware: ['morphos-core'] })

const db = useDb()
const usuario = useMorphosUser()
const dinero = useFormatoDinero()
const fechaFmt = useFormatoFecha()
const { t } = useI18n()

useHead({ title: () => t('egresos.titulo') })

const { data: egresos, refresh } = await useAsyncData('global:egresos', async () => {
  const { data } = await db
    .from('egresos_morphos')
    .select('*')
    .order('fecha', { ascending: false })
    .limit(100)
  return (data ?? []) as EgresoMorphos[]
})

const abriendo = ref(false)
const guardando = ref(false)
const error = ref('')

const concepto = ref('')
const importe = ref<number>(0)
const categoria = ref<EgresoCategoria>('infraestructura')
const fecha = ref(isoDate(new Date()))

const categorias = computed(() =>
  (['infraestructura', 'nomina', 'proveedores', 'comisiones', 'otros'] as const).map(v => ({
    label: t(`egresos.cat.${v}`),
    value: v,
  })),
)

// Alta manual: cubre el bloque de recaudo mensual sin construir un ERP
// (docs/spec/30-comercial.md §5).
async function crear() {
  if (!usuario.value?.id || !concepto.value.trim()) return
  guardando.value = true
  error.value = ''

  const { error: err } = await db.from('egresos_morphos').insert({
    concepto: concepto.value.trim(),
    importe: Number(importe.value),
    categoria: categoria.value,
    fecha: fecha.value,
    registrado_por: usuario.value.id,
  })

  guardando.value = false
  if (err) {
    error.value = err.message
    return
  }

  concepto.value = ''
  importe.value = 0
  abriendo.value = false
  await refresh()
}

const total = computed(() =>
  (egresos.value ?? []).reduce((s, e) => s + Number(e.importe), 0),
)
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader :titulo="$t('egresos.titulo')">
      <template #acciones>
        <UButton
          size="sm"
          icon="i-lucide-plus"
          :label="$t('egresos.nuevo')"
          @click="abriendo = !abriendo"
        />
      </template>
    </AppHeader>

    <div v-auto-animate>
      <UCard v-if="abriendo">
        <form
          class="grid gap-3 sm:grid-cols-5 sm:items-end"
          @submit.prevent="crear"
        >
          <UFormField
            :label="$t('egresos.concepto')"
            class="sm:col-span-2"
          >
            <UInput
              v-model="concepto"
              required
              class="w-full"
            />
          </UFormField>

          <UFormField :label="$t('egresos.categoria')">
            <USelect
              v-model="categoria"
              :items="categorias"
              value-key="value"
              class="w-full"
            />
          </UFormField>

          <UFormField :label="$t('egresos.importe')">
            <UInput
              v-model.number="importe"
              type="number"
              step="0.01"
              required
              class="w-full"
            />
          </UFormField>

          <UButton
            type="submit"
            :loading="guardando"
            :label="$t('comun.crear')"
          />
        </form>

        <p
          v-if="error"
          class="mt-3 rounded-lg bg-error/10 px-3 py-2 text-sm text-error"
        >
          {{ error }}
        </p>
      </UCard>
    </div>

    <UCard>
      <template #header>
        <div class="flex items-center justify-between">
          <h2 class="font-medium">
            {{ $t('egresos.titulo') }}
          </h2>
          <p class="text-sm tabular-nums text-muted">
            {{ $t('comun.total') }}: {{ dinero(total) }}
          </p>
        </div>
      </template>

      <ul
        v-auto-animate
        class="divide-y divide-default/60 text-sm"
      >
        <li
          v-for="e in egresos"
          :key="e.id"
          class="flex items-center justify-between gap-3 py-2"
        >
          <div>
            <p>{{ e.concepto }}</p>
            <p class="text-xs text-dimmed">
              {{ $t(`egresos.cat.${e.categoria}`) }} · {{ fechaFmt(e.fecha) }}
            </p>
          </div>
          <p class="tabular-nums text-error">
            −{{ dinero(Number(e.importe)) }}
          </p>
        </li>
      </ul>

      <p
        v-if="!egresos?.length"
        class="py-8 text-center text-sm text-muted"
      >
        {{ $t('dashboard.sinDatos') }}
      </p>
    </UCard>
  </div>
</template>
