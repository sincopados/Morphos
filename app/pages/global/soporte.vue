<script setup lang="ts">
import type { Empresa, Incidencia, Usuario } from '#shared/types/database'

definePageMeta({ layout: 'global', middleware: ['morphos-core'] })

const db = useDb()
const usuario = useMorphosUser()
const fechaFmt = useFormatoFecha()
const { t } = useI18n()

useHead({ title: () => t('soporte.titulo') })

interface Fila extends Incidencia {
  empresas: Empresa | null
  abierta: Usuario | null
}

const soloAbiertas = ref(true)

const { data: incidencias, refresh } = await useAsyncData(
  () => `global:soporte:${soloAbiertas.value}`,
  async () => {
    let query = db
      .from('incidencias')
      .select('*, empresas(*), abierta:usuarios!incidencias_abierta_por_fkey(*)')
      .order('prioridad', { ascending: false })
      .order('created_at')

    if (soloAbiertas.value) query = query.neq('estado', 'cerrada')

    const { data } = await query
    return (data ?? []) as unknown as Fila[]
  },
  { watch: [soloAbiertas] },
)

function antiguedad(iso: string) {
  const dias = Math.floor((Date.now() - new Date(iso).getTime()) / 864e5)
  return `${dias} ${t('comun.dias')}`
}

async function asignarme(inc: Fila) {
  if (!usuario.value?.id) return
  await db
    .from('incidencias')
    .update({ responsable: usuario.value.id, estado: 'en_curso' })
    .eq('id', inc.id)
  await refresh()
}

async function cerrar(inc: Fila) {
  await db
    .from('incidencias')
    .update({ estado: 'cerrada', cerrada_en: new Date().toISOString() })
    .eq('id', inc.id)
  await refresh()
}
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('global.alertasSoporte')"
      :subtitulo="$t('soporte.titulo')"
    >
      <template #acciones>
        <USwitch
          v-model="soloAbiertas"
          :label="$t('soporte.sinIncidencias')"
        />
      </template>
    </AppHeader>

    <UCard>
      <ul
        v-auto-animate
        class="divide-y divide-default/60 text-sm"
      >
        <li
          v-for="inc in incidencias"
          :key="inc.id"
          class="flex flex-wrap items-center justify-between gap-3 py-3"
        >
          <div class="min-w-0">
            <p class="font-medium">
              {{ inc.asunto }}
            </p>
            <p class="text-xs text-dimmed">
              {{ inc.empresas?.nombre }} ·
              {{ $t('soporte.abiertaPor') }} {{ inc.abierta?.nombre }} ·
              {{ fechaFmt(inc.created_at) }} · {{ antiguedad(inc.created_at) }}
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
              color="neutral"
              variant="subtle"
              size="sm"
            >
              {{ $t(`soporte.tipo.${inc.tipo}`) }}
            </UBadge>

            <UButton
              v-if="inc.estado !== 'cerrada'"
              size="xs"
              variant="ghost"
              color="neutral"
              icon="i-lucide-user-check"
              :title="$t('soporte.responsable')"
              @click="asignarme(inc)"
            />
            <UButton
              v-if="inc.estado !== 'cerrada'"
              size="xs"
              variant="ghost"
              icon="i-lucide-check"
              :title="$t('soporte.cerrar')"
              @click="cerrar(inc)"
            />
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
