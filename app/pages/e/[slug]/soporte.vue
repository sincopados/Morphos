<script setup lang="ts">
import type { Incidencia, IncidenciaTipo } from '#shared/types/database'

definePageMeta({ middleware: ['empresa'] })

const { empresa } = useEmpresaActiva()
const usuario = useMorphosUser()
const db = useDb()
const fecha = useFormatoFecha()
const { t } = useI18n()

useHead({ title: () => t('soporte.titulo') })

const { data: incidencias, refresh } = await useAsyncData(
  () => `incidencias:${empresa.value?.id}`,
  async () => {
    if (!empresa.value?.id) return []
    const { data } = await db
      .from('incidencias')
      .select('*')
      .eq('empresa_id', empresa.value.id)
      .order('created_at', { ascending: false })
    return (data ?? []) as Incidencia[]
  },
  { watch: [empresa] },
)

const abriendo = ref(false)
const asunto = ref('')
const tipo = ref<IncidenciaTipo>('otro')
const guardando = ref(false)

const tipos = computed(() =>
  (['pago', 'saldo', 'datos', 'tecnico', 'otro'] as const).map(v => ({
    label: t(`soporte.tipo.${v}`),
    value: v,
  })),
)

// Cualquier rol abre incidencias sobre su empresa (docs/spec/30 §4).
async function crear() {
  if (!empresa.value?.id || !usuario.value?.id || !asunto.value.trim()) return
  guardando.value = true

  await db.from('incidencias').insert({
    empresa_id: empresa.value.id,
    abierta_por: usuario.value.id,
    asunto: asunto.value.trim(),
    tipo: tipo.value,
  })

  asunto.value = ''
  tipo.value = 'otro'
  abriendo.value = false
  guardando.value = false
  await refresh()
}
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('soporte.titulo')"
      :subtitulo="empresa?.nombre"
    >
      <template #acciones>
        <UButton
          size="sm"
          icon="i-lucide-plus"
          :label="$t('soporte.nueva')"
          @click="abriendo = !abriendo"
        />
      </template>
    </AppHeader>

    <div v-auto-animate>
      <UCard v-if="abriendo">
        <form
          class="flex flex-col gap-3 sm:flex-row sm:items-end"
          @submit.prevent="crear"
        >
          <UFormField
            :label="$t('soporte.asunto')"
            class="flex-1"
          >
            <UInput
              v-model="asunto"
              required
              class="w-full"
            />
          </UFormField>

          <UFormField :label="$t('egresos.categoria')">
            <USelect
              v-model="tipo"
              :items="tipos"
              value-key="value"
            />
          </UFormField>

          <UButton
            type="submit"
            :loading="guardando"
            :label="$t('comun.crear')"
          />
        </form>
      </UCard>
    </div>

    <UCard>
      <ul
        v-auto-animate
        class="divide-y divide-default/60 text-sm"
      >
        <li
          v-for="inc in incidencias"
          :key="inc.id"
          class="flex items-center justify-between gap-4 py-3"
        >
          <div>
            <p class="font-medium">
              {{ inc.asunto }}
            </p>
            <p class="text-xs text-dimmed">
              {{ $t(`soporte.tipo.${inc.tipo}`) }} · {{ fecha(inc.created_at) }}
            </p>
          </div>
          <div class="flex items-center gap-2">
            <UBadge
              :color="inc.prioridad === 'alta' ? 'error' : 'neutral'"
              variant="subtle"
              size="sm"
            >
              {{ $t(`soporte.prio.${inc.prioridad}`) }}
            </UBadge>
            <UBadge
              :color="inc.estado === 'cerrada' ? 'neutral' : 'info'"
              variant="subtle"
              size="sm"
            >
              {{ inc.estado }}
            </UBadge>
          </div>
        </li>
      </ul>

      <p
        v-if="!incidencias?.length"
        class="py-8 text-center text-sm text-muted"
      >
        {{ $t('soporte.sinIncidencias') }}
      </p>
    </UCard>
  </div>
</template>
