<script setup lang="ts">
import type { Pertenencia, Usuario } from '#shared/types/database'

definePageMeta({ middleware: ['empresa'] })

const { empresa, rol } = useEmpresaActiva()
const db = useDb()
const dinero = useFormatoDinero()
const { t } = useI18n()

if (rol.value !== 'owner' && !useEsMorphosCore().value) {
  throw createError({ statusCode: 404, statusMessage: 'Not Found' })
}

useHead({ title: () => t('nav.equipo') })

interface Fila extends Pertenencia {
  usuarios: Usuario | null
}

const { data: equipo } = await useAsyncData(
  () => `equipo:${empresa.value?.id}`,
  async () => {
    if (!empresa.value?.id) return []
    const { data } = await db
      .from('pertenencias')
      .select('*, usuarios(*)')
      .eq('empresa_id', empresa.value.id)
    return (data ?? []) as unknown as Fila[]
  },
  { watch: [empresa] },
)
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('nav.equipo')"
      :subtitulo="empresa?.nombre"
    />

    <p class="text-xs text-dimmed">
      {{ $t('saldo.explicacion') }}
    </p>

    <UCard>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="text-left text-xs uppercase tracking-wide text-dimmed">
            <tr>
              <th class="pb-2 font-medium">
                {{ $t('usuarios.nombre') }}
              </th>
              <th class="pb-2 font-medium">
                {{ $t('usuarios.rolGlobal') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('usuarios.tarifa') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('usuarios.activo') }}
              </th>
            </tr>
          </thead>
          <tbody v-auto-animate>
            <tr
              v-for="fila in equipo"
              :key="fila.id"
              class="border-t border-default/60"
            >
              <td class="py-2">
                <p class="font-medium">
                  {{ fila.usuarios?.nombre }}
                </p>
                <p class="text-xs text-dimmed">
                  {{ fila.usuarios?.email }}
                </p>
              </td>
              <td class="py-2">
                <UBadge
                  color="neutral"
                  variant="subtle"
                  size="sm"
                >
                  {{ $t(`rol.${fila.rol}`) }}
                </UBadge>
                <span class="ml-2 text-xs text-dimmed">{{ fila.perfil }}</span>
              </td>
              <td class="py-2 text-right tabular-nums">
                {{ dinero(Number(fila.tarifa_hora)) }}
              </td>
              <td class="py-2 text-right">
                <UIcon
                  :name="fila.activa ? 'i-lucide-check' : 'i-lucide-x'"
                  class="size-4"
                  :class="fila.activa ? 'text-success' : 'text-dimmed'"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </UCard>
  </div>
</template>
