<script setup lang="ts">
import type { Empresa, Membresia } from '#shared/types/database'

definePageMeta({ layout: 'global', middleware: ['morphos-core'] })

const db = useDb()
const fecha = useFormatoFecha()
const { t } = useI18n()

useHead({ title: () => t('empresas.titulo') })

interface Fila extends Empresa {
  membresias: Membresia[]
  pertenencias: { id: string }[]
  obras: { id: string }[]
}

const busqueda = ref('')

const { data: empresas } = await useAsyncData('global:empresas', async () => {
  const { data } = await db
    .from('empresas')
    .select('*, membresias(*), pertenencias(id), obras(id)')
    .order('nombre')
  return (data ?? []) as unknown as Fila[]
})

const filtradas = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  const lista = empresas.value ?? []
  if (!q) return lista
  return lista.filter(e => e.nombre.toLowerCase().includes(q))
})
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader :titulo="$t('empresas.titulo')">
      <template #acciones>
        <UInput
          v-model="busqueda"
          icon="i-lucide-search"
          size="sm"
          :placeholder="$t('comun.buscar')"
        />
      </template>
    </AppHeader>

    <UCard>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="text-left text-xs uppercase tracking-wide text-dimmed">
            <tr>
              <th class="pb-2 font-medium">
                {{ $t('empresas.nombre') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('empresas.equipo') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('empresas.obras') }}
              </th>
              <th class="pb-2 font-medium">
                {{ $t('empresas.vence') }}
              </th>
              <th class="pb-2 font-medium">
                {{ $t('empresas.compliance') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('comun.acciones') }}
              </th>
            </tr>
          </thead>
          <tbody v-auto-animate>
            <tr
              v-for="e in filtradas"
              :key="e.id"
              class="border-t border-default/60"
            >
              <td class="py-2">
                <p class="font-medium">
                  {{ e.nombre }}
                </p>
                <p class="mt-0.5 flex items-center gap-2 text-xs text-dimmed">
                  {{ e.jurisdiccion }}
                  <EstadoBadge :estado="e.estado" />
                </p>
              </td>
              <td class="py-2 text-right tabular-nums">
                {{ e.pertenencias?.length ?? 0 }}
              </td>
              <td class="py-2 text-right tabular-nums">
                {{ e.obras?.length ?? 0 }}
              </td>
              <td class="py-2 text-xs">
                {{ fecha(e.membresias?.[0]?.vence_el ?? null) }}
              </td>
              <td class="py-2">
                <UBadge
                  v-if="!e.compliance_cargado"
                  color="warning"
                  variant="subtle"
                  size="sm"
                >
                  {{ $t('empresas.faltaCompliance') }}
                </UBadge>
                <UIcon
                  v-else
                  name="i-lucide-check"
                  class="size-4 text-success"
                />
              </td>
              <td class="py-2 text-right">
                <UButton
                  size="xs"
                  variant="subtle"
                  :to="`/global/empresas/${e.id}`"
                  :label="$t('empresas.entrar')"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </UCard>
  </div>
</template>
