<script setup lang="ts">
import type { Empresa, Pertenencia, Usuario } from '#shared/types/database'

definePageMeta({ layout: 'global', middleware: ['morphos-core'] })

const db = useDb()
const { t } = useI18n()

useHead({ title: () => t('usuarios.titulo') })

interface UsuarioConPertenencias extends Usuario {
  pertenencias: (Pertenencia & { empresas: Empresa | null })[]
}

const busqueda = ref('')
const error = ref('')

const { data: usuarios, refresh } = await useAsyncData('global:usuarios', async () => {
  const { data } = await db
    .from('usuarios')
    .select('*, pertenencias(*, empresas(*))')
    .order('created_at', { ascending: false })
  return (data ?? []) as unknown as UsuarioConPertenencias[]
})

const filtrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  const lista = usuarios.value ?? []
  if (!q) return lista
  return lista.filter(
    u => u.nombre.toLowerCase().includes(q) || u.email.toLowerCase().includes(q),
  )
})

/**
 * El trigger de base de datos rechaza asignar morphos_core a alguien con
 * pertenencias activas, y proteger la cuenta raíz (ADR-0002). Aquí solo
 * anticipamos el error para no ofrecer una acción que va a fallar.
 */
function puedeSerCore(u: UsuarioConPertenencias) {
  return !u.pertenencias.some(p => p.activa)
}

async function alternarCore(u: UsuarioConPertenencias) {
  error.value = ''
  const nuevo = u.rol_global === 'morphos_core' ? null : 'morphos_core'

  const { error: err } = await db
    .from('usuarios')
    .update({ rol_global: nuevo })
    .eq('id', u.id)

  if (err) {
    error.value = err.message
    return
  }
  await refresh()
}

// Borrado lógico: conserva historial y auditoría (docs/spec/40 §2).
async function desactivar(u: UsuarioConPertenencias) {
  error.value = ''
  const { error: err } = await db
    .from('usuarios')
    .update({ activo: false, eliminado_en: new Date().toISOString() })
    .eq('id', u.id)

  if (err) {
    error.value = err.message
    return
  }
  await refresh()
}
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('usuarios.titulo')"
      :subtitulo="$t('usuarios.subtitulo')"
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

    <div v-auto-animate>
      <p
        v-if="error"
        class="rounded-lg bg-error/10 px-3 py-2 text-sm text-error"
      >
        {{ error }}
      </p>
    </div>

    <p class="text-xs text-dimmed">
      {{ $t('usuarios.excluyente') }} · {{ $t('usuarios.raizProtegida') }}
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
                {{ $t('usuarios.pertenencias') }}
              </th>
              <th class="pb-2 font-medium">
                {{ $t('usuarios.rolGlobal') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('comun.acciones') }}
              </th>
            </tr>
          </thead>
          <tbody v-auto-animate>
            <tr
              v-for="u in filtrados"
              :key="u.id"
              class="border-t border-default/60"
              :class="{ 'opacity-50': !u.activo }"
            >
              <td class="py-2">
                <p class="flex items-center gap-2 font-medium">
                  {{ u.nombre }}
                  <UIcon
                    v-if="u.es_raiz"
                    name="i-lucide-shield"
                    class="size-3.5 text-primary"
                    :title="$t('usuarios.raiz')"
                  />
                </p>
                <p class="text-xs text-dimmed">
                  {{ u.email }}
                </p>
              </td>

              <td class="py-2">
                <div
                  v-auto-animate
                  class="flex flex-wrap gap-1"
                >
                  <UBadge
                    v-for="p in u.pertenencias"
                    :key="p.id"
                    color="neutral"
                    variant="subtle"
                    size="sm"
                  >
                    {{ p.empresas?.nombre }} · {{ $t(`rol.${p.rol}`) }}
                  </UBadge>
                  <span
                    v-if="!u.pertenencias.length"
                    class="text-xs text-dimmed"
                  >
                    {{ $t('usuarios.sinPertenencias') }}
                  </span>
                </div>
              </td>

              <td class="py-2">
                <UBadge
                  v-if="u.rol_global"
                  color="primary"
                  variant="subtle"
                  size="sm"
                >
                  {{ $t('rol.morphos_core') }}
                </UBadge>
                <span
                  v-else
                  class="text-xs text-dimmed"
                >—</span>
              </td>

              <td class="py-2">
                <div class="flex justify-end gap-1">
                  <UButton
                    size="xs"
                    variant="ghost"
                    color="neutral"
                    :disabled="u.es_raiz || (!u.rol_global && !puedeSerCore(u))"
                    :icon="u.rol_global ? 'i-lucide-shield-off' : 'i-lucide-shield-plus'"
                    :title="$t('rol.morphos_core')"
                    @click="alternarCore(u)"
                  />
                  <UButton
                    size="xs"
                    variant="ghost"
                    color="error"
                    icon="i-lucide-trash-2"
                    :disabled="u.es_raiz || !u.activo"
                    :title="$t('usuarios.eliminarLogico')"
                    @click="desactivar(u)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </UCard>
  </div>
</template>
