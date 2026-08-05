<script setup lang="ts">
import type { UsuarioConPertenencias } from '~/composables/useMorphos'
import type { Empresa } from '#shared/types/database'

definePageMeta({ layout: 'global', middleware: ['morphos-core'] })

const db = useDb()
const { t } = useI18n()

useHead({ title: () => t('usuarios.titulo') })

const busqueda = ref('')
const error = ref('')

const { data, refresh } = await useAsyncData('global:usuarios', async () => {
  const [usuarios, empresas] = await Promise.all([
    db.from('usuarios').select('*, pertenencias(*, empresas(*))').order('created_at', { ascending: false }),
    db.from('empresas').select('*').order('nombre'),
  ])

  return {
    usuarios: (usuarios.data ?? []) as unknown as UsuarioConPertenencias[],
    empresas: (empresas.data ?? []) as Empresa[],
  }
})

const filtrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  const lista = data.value?.usuarios ?? []
  if (!q) return lista
  return lista.filter(
    u => u.nombre.toLowerCase().includes(q) || u.email.toLowerCase().includes(q),
  )
})

// --- Modal ------------------------------------------------------------------

const modalAbierto = ref(false)
const enEdicion = ref<UsuarioConPertenencias | null>(null)

function editar(u: UsuarioConPertenencias) {
  enEdicion.value = u
  modalAbierto.value = true
}

function crear() {
  enEdicion.value = null
  modalAbierto.value = true
}

async function trasGuardar() {
  error.value = ''
  await refresh()
}

// --- Acciones rápidas -------------------------------------------------------

/**
 * El trigger de base de datos rechaza asignar morphos_core a alguien con
 * pertenencias activas y proteger la cuenta raíz (ADR-0002). Aquí solo
 * anticipamos el error para no ofrecer una acción que va a fallar.
 */
function puedeSerCore(u: UsuarioConPertenencias) {
  return !u.pertenencias.some(p => p.activa)
}

async function alternarCore(u: UsuarioConPertenencias) {
  error.value = ''
  const { error: err } = await db
    .from('usuarios')
    .update({ rol_global: u.rol_global === 'morphos_core' ? null : 'morphos_core' })
    .eq('id', u.id)

  if (err) {
    error.value = err.message
    return
  }
  await refresh()
}

/**
 * Activa o desactiva la cuenta. Un usuario inactivo no entra al sistema: las
 * políticas RLS dejan de devolverle nada (migración 0007) y el middleware le
 * cierra la sesión. No es cosmético.
 */
async function alternarActivo(u: UsuarioConPertenencias) {
  error.value = ''
  const activar = !u.activo

  const { error: err } = await db
    .from('usuarios')
    .update({
      activo: activar,
      eliminado_en: activar ? null : new Date().toISOString(),
    })
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
        <UButton
          size="sm"
          icon="i-lucide-user-plus"
          :label="$t('usuarios.nuevo')"
          @click="crear"
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
                    icon="i-lucide-pencil"
                    :title="$t('usuarios.editar')"
                    @click="editar(u)"
                  />

                  <!-- La cuenta raíz no se puede suspender (ADR-0002) -->
                  <USwitch
                    :model-value="u.activo"
                    :disabled="u.es_raiz"
                    size="sm"
                    class="mx-1"
                    :title="u.activo ? $t('usuarios.desactivarAyuda') : $t('usuarios.activarAyuda')"
                    :aria-label="$t('usuarios.activo')"
                    @update:model-value="alternarActivo(u)"
                  />

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

    <UsuarioModal
      v-model:open="modalAbierto"
      :usuario="enEdicion"
      :empresas="data?.empresas ?? []"
      @guardado="trasGuardar"
    />
  </div>
</template>
