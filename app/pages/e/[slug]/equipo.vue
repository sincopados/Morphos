<script setup lang="ts">
import type { MiembroEquipo } from '~/composables/useMorphos'

definePageMeta({ middleware: ['empresa'] })

const { empresa, rol } = useEmpresaActiva()
const esCore = useEsMorphosCore()
const db = useDb()
const dinero = useFormatoDinero()
const { t } = useI18n()

const esOwner = computed(() => rol.value === 'owner')

if (!esOwner.value && !esCore.value) {
  throw createError({ statusCode: 404, statusMessage: 'Not Found' })
}

useHead({ title: () => t('nav.equipo') })

const error = ref('')

const { data: equipo, refresh } = await useAsyncData(
  () => `equipo:${empresa.value?.id}`,
  async () => {
    if (!empresa.value?.id) return []
    const { data } = await db
      .from('pertenencias')
      // `bloques(count)` decide si se puede eliminar sin destruir historial.
      .select('*, usuarios(*), bloques(count)')
      .eq('empresa_id', empresa.value.id)
      .order('created_at')
    return (data ?? []) as unknown as MiembroEquipo[]
  },
  { watch: [empresa] },
)

// Con la empresa bloqueada nadie escribe (ADR-0001); `morphos_core` sí.
const puedeEditar = computed(
  () => esCore.value || (esOwner.value && empresa.value?.estado === 'activa'),
)

const modalAbierto = ref(false)
const enEdicion = ref<MiembroEquipo | null>(null)

function crear() {
  enEdicion.value = null
  modalAbierto.value = true
}

function editar(m: MiembroEquipo) {
  enEdicion.value = m
  modalAbierto.value = true
}

/**
 * Cambia el estado de la PERTENENCIA, no el de la persona.
 *
 * `usuarios.activo` es global: apagarlo echaría a alguien de todo MORPHOS,
 * incluidas las demás empresas para las que trabaje. Un owner no tiene por qué
 * poder hacer eso — y RLS ya se lo impide. Lo que sí le corresponde es dar o
 * quitar el acceso a SU empresa.
 */
async function alternarPertenencia(m: MiembroEquipo) {
  error.value = ''
  const { error: err } = await db
    .from('pertenencias')
    .update({ activa: !m.activa })
    .eq('id', m.id)

  if (err) {
    error.value = err.message
    return
  }
  await refresh()
}

// --- Eliminar de la empresa -------------------------------------------------

const aEliminar = ref<MiembroEquipo | null>(null)
const eliminando = ref(false)

/**
 * `bloques.pertenencia_id` borra en CASCADA: eliminar a alguien con fichajes se
 * llevaría por delante su historial y la mano de obra ya imputada a las obras,
 * cambiando cuentas cerradas hacia atrás. Con historial, el camino es quitarle
 * el acceso con el interruptor, no borrarlo.
 */
function sePuedeEliminar(m: MiembroEquipo) {
  return m.rol !== 'owner' && bloquesDe(m) === 0
}

function pedirEliminar(m: MiembroEquipo) {
  aEliminar.value = m
}

async function eliminar() {
  if (!aEliminar.value) return
  eliminando.value = true
  error.value = ''

  const { error: err } = await db
    .from('pertenencias')
    .delete()
    .eq('id', aEliminar.value.id)

  eliminando.value = false

  if (err) {
    error.value = err.message
    return
  }

  aEliminar.value = null
  await refresh()
}

async function trasGuardar() {
  error.value = ''
  await refresh()
}
</script>

<template>
  <div class="flex flex-col gap-6">
    <AppHeader
      :titulo="$t('nav.equipo')"
      :subtitulo="empresa?.nombre"
    >
      <template #acciones>
        <UButton
          v-if="puedeEditar"
          size="sm"
          icon="i-lucide-user-plus"
          :label="$t('equipo.nuevo')"
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
      {{ $t('equipo.ayuda') }}
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
                {{ $t('usuarios.rolEnEmpresa') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('usuarios.tarifa') }}
              </th>
              <th class="pb-2 text-right font-medium">
                {{ $t('comun.acciones') }}
              </th>
            </tr>
          </thead>
          <tbody v-auto-animate>
            <tr
              v-for="m in equipo"
              :key="m.id"
              class="border-t border-default/60"
              :class="{ 'opacity-50': !m.activa }"
            >
              <td class="py-2">
                <p class="font-medium">
                  {{ m.usuarios?.nombre }}
                </p>
                <p class="text-xs text-dimmed">
                  {{ m.usuarios?.email }}
                  <!-- Cuenta suspendida en todo MORPHOS: el owner no lo decide
                       ni lo puede revertir desde aquí -->
                  <span
                    v-if="m.usuarios && !m.usuarios.activo"
                    class="ml-1 text-warning"
                  >· {{ $t('equipo.cuentaSuspendida') }}</span>
                </p>
              </td>

              <td class="py-2">
                <UBadge
                  color="neutral"
                  variant="subtle"
                  size="sm"
                >
                  {{ $t(`rol.${m.rol}`) }}
                </UBadge>
                <span class="ml-2 text-xs text-dimmed">{{ m.perfil }}</span>
              </td>

              <td class="py-2 text-right tabular-nums">
                {{ dinero(Number(m.tarifa_hora)) }}
              </td>

              <td class="py-2">
                <div class="flex items-center justify-end gap-2">
                  <USwitch
                    v-if="puedeEditar && m.rol !== 'owner'"
                    :model-value="m.activa"
                    size="sm"
                    :title="m.activa ? $t('equipo.quitarAcceso') : $t('equipo.darAcceso')"
                    :aria-label="$t('equipo.enLaEmpresa')"
                    @update:model-value="alternarPertenencia(m)"
                  />
                  <UIcon
                    v-else
                    :name="m.activa ? 'i-lucide-check' : 'i-lucide-x'"
                    class="size-4"
                    :class="m.activa ? 'text-success' : 'text-dimmed'"
                    :title="$t('equipo.enLaEmpresa')"
                  />

                  <UButton
                    v-if="puedeEditar"
                    size="xs"
                    variant="ghost"
                    color="neutral"
                    icon="i-lucide-pencil"
                    :disabled="m.rol === 'owner'"
                    :title="$t('equipo.editar')"
                    @click="editar(m)"
                  />

                  <UButton
                    v-if="puedeEditar"
                    size="xs"
                    variant="ghost"
                    color="error"
                    icon="i-lucide-trash-2"
                    :disabled="!sePuedeEliminar(m)"
                    :title="m.rol === 'owner'
                      ? $t('equipo.noBorrarOwner')
                      : bloquesDe(m) > 0
                        ? $t('equipo.conHistorial', { n: bloquesDe(m) })
                        : $t('equipo.eliminar')"
                    @click="pedirEliminar(m)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </UCard>

    <EquipoModal
      v-if="empresa"
      v-model:open="modalAbierto"
      :miembro="enEdicion"
      :empresa-id="empresa.id"
      @guardado="trasGuardar"
    />

    <!-- Confirmación: quitar a alguien de la empresa no se deshace -->
    <UModal
      :open="aEliminar !== null"
      :title="$t('equipo.eliminar')"
      :description="aEliminar?.usuarios?.nombre ?? ''"
      @update:open="aEliminar = null"
    >
      <template #body>
        <p class="text-sm text-muted">
          {{ $t('equipo.eliminarConfirmar', {
            nombre: aEliminar?.usuarios?.nombre ?? '',
            empresa: empresa?.nombre ?? '',
          }) }}
        </p>
        <p class="mt-2 text-xs text-dimmed">
          {{ $t('equipo.eliminarNoBorraCuenta') }}
        </p>
      </template>

      <template #footer>
        <div class="flex w-full justify-end gap-2">
          <UButton
            color="neutral"
            variant="ghost"
            :label="$t('comun.cancelar')"
            @click="aEliminar = null"
          />
          <UButton
            color="error"
            :loading="eliminando"
            :label="$t('equipo.eliminar')"
            @click="eliminar"
          />
        </div>
      </template>
    </UModal>
  </div>
</template>
