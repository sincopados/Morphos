<script setup lang="ts">
import type { UsuarioConPertenencias } from '~/composables/useMorphos'
import type { Empresa, ProfileType, UserRole } from '#shared/types/database'

const props = defineProps<{
  /** `null` abre el modal en modo alta. */
  usuario: UsuarioConPertenencias | null
  empresas: Empresa[]
}>()

const emit = defineEmits<{ guardado: [] }>()

const abierto = defineModel<boolean>('open', { default: false })

const db = useDb()
const { t } = useI18n()

const esAlta = computed(() => props.usuario === null)
const guardando = ref(false)
const error = ref('')

// --- Campos -----------------------------------------------------------------

const nombre = ref('')
const email = ref('')
const password = ref('')
const activo = ref(true)
const esCore = ref(false)

/** Copia editable de las pertenencias: nada se guarda hasta pulsar Guardar. */
interface FilaPertenencia {
  id: string | null
  empresa_id: string
  rol: UserRole
  tarifa_hora: number
  activa: boolean
}
const filas = ref<FilaPertenencia[]>([])
const eliminadas = ref<string[]>([])

const roles: UserRole[] = ['owner', 'administrador', 'trabajador', 'vendedor', 'afiliado']

/** Roles elegidos en el alta. `morphos_core` es global; el resto, por empresa. */
type RolSistema = UserRole | 'morphos_core'
const rolesElegidos = ref<RolSistema[]>([])

watch(abierto, (v) => {
  if (!v) return
  error.value = ''
  password.value = ''

  const u = props.usuario
  nombre.value = u?.nombre ?? ''
  email.value = u?.email ?? ''
  activo.value = u?.activo ?? true
  esCore.value = u?.rol_global === 'morphos_core'
  eliminadas.value = []
  rolesElegidos.value = []
  filas.value = (u?.pertenencias ?? []).map(p => ({
    id: p.id,
    empresa_id: p.empresa_id,
    rol: p.rol,
    tarifa_hora: Number(p.tarifa_hora),
    activa: p.activa,
  }))
}, { immediate: true })

/**
 * El multiselect manda sobre las filas del alta: una fila por rol elegido.
 * Cada rol necesita su propia empresa porque `pertenencias` es única por
 * (usuario, empresa) — nadie puede tener dos roles en la misma empresa.
 */
watch(rolesElegidos, (elegidos, previos) => {
  if (!esAlta.value) return

  // morphos_core es excluyente (ADR-0002): al marcarlo, descarta el resto.
  if (elegidos.includes('morphos_core') && elegidos.length > 1) {
    const acabaDeMarcarlo = !previos?.includes('morphos_core')
    rolesElegidos.value = acabaDeMarcarlo
      ? ['morphos_core']
      : elegidos.filter(r => r !== 'morphos_core')
    return
  }

  esCore.value = elegidos.includes('morphos_core')

  const porEmpresa = roles.filter(r => elegidos.includes(r))
  filas.value = porEmpresa.map((rol) => {
    const previa = filas.value.find(f => f.rol === rol)
    return previa ?? {
      id: null,
      empresa_id: '',
      rol,
      tarifa_hora: 0,
      activa: true,
    }
  })
})

const opcionesRol = computed(() =>
  roles.map(r => ({ label: t(`rol.${r}`), value: r as RolSistema })),
)

/** En el alta también se ofrece el rol global; en la edición tiene su switch. */
const opcionesRolSistema = computed(() => [
  ...opcionesRol.value,
  { label: t('rol.morphos_core'), value: 'morphos_core' as RolSistema },
])

const opcionesEmpresa = computed(() =>
  props.empresas.map(e => ({ label: e.nombre, value: e.id })),
)

const empresasLibres = computed(() =>
  props.empresas.filter(e => !filas.value.some(f => f.empresa_id === e.id)),
)

// El perfil se deriva del rol, no se pregunta: `con_horario` es exactamente
// quien ficha por bloques (docs/spec/10 §4).
function perfilDe(rol: UserRole): ProfileType {
  return rol === 'trabajador' ? 'con_horario' : 'sin_horario'
}

const conflictoCore = computed(() => esCore.value && filas.value.length > 0)
const esRaiz = computed(() => props.usuario?.es_raiz === true)

function anadirPertenencia() {
  const libre = empresasLibres.value[0]
  if (!libre) return
  filas.value.push({
    id: null,
    empresa_id: libre.id,
    rol: 'trabajador',
    tarifa_hora: 0,
    activa: true,
  })
}

function quitarPertenencia(indice: number) {
  const fila = filas.value[indice]
  if (fila?.id) eliminadas.value.push(fila.id)
  filas.value.splice(indice, 1)

  if (esAlta.value && fila) {
    rolesElegidos.value = rolesElegidos.value.filter(r => r !== fila.rol)
  }
}

// --- Guardar ----------------------------------------------------------------

function validar(): string | null {
  if (!nombre.value.trim()) return t('usuarios.errorNombre')
  if (conflictoCore.value) return t('usuarios.excluyente')

  if (filas.value.some(f => !f.empresa_id)) return t('usuarios.errorSinEmpresa')

  const empresasUsadas = filas.value.map(f => f.empresa_id)
  if (new Set(empresasUsadas).size !== empresasUsadas.length) {
    return t('usuarios.errorEmpresaDuplicada')
  }

  return null
}

async function guardar() {
  error.value = validar() ?? ''
  if (error.value) return

  guardando.value = true

  try {
    const id = esAlta.value
      ? await crearCuenta()
      : props.usuario!.id

    if (!esAlta.value || esCore.value) {
      const { error: err } = await db
        .from('usuarios')
        .update({
          nombre: nombre.value.trim(),
          activo: activo.value,
          rol_global: esCore.value ? 'morphos_core' : null,
        })
        .eq('id', id)

      if (err) throw new Error(err.message)
    }

    for (const idPertenencia of eliminadas.value) {
      const { error: err } = await db.from('pertenencias').delete().eq('id', idPertenencia)
      if (err) throw new Error(err.message)
    }

    for (const fila of filas.value) {
      const payload = {
        usuario_id: id,
        empresa_id: fila.empresa_id,
        rol: fila.rol,
        perfil: perfilDe(fila.rol),
        tarifa_hora: Number(fila.tarifa_hora) || 0,
        activa: fila.activa,
      }

      const { error: err } = fila.id
        ? await db.from('pertenencias').update(payload).eq('id', fila.id)
        : await db.from('pertenencias').insert(payload)

      if (err) throw new Error(err.message)
    }

    emit('guardado')
    abierto.value = false
  }
  catch (e) {
    error.value = mensajeDeError(e)
  }
  finally {
    guardando.value = false
  }
}

/** Crear la cuenta exige la clave de servicio: va por el servidor. */
async function crearCuenta() {
  const creado = await $fetch<{ id: string }>('/api/global/usuarios', {
    method: 'POST',
    body: {
      email: email.value,
      password: password.value,
      nombre: nombre.value.trim(),
    },
  })
  return creado.id
}

function mensajeDeError(e: unknown) {
  const conDatos = e as { statusMessage?: string, data?: { statusMessage?: string }, message?: string }
  return conDatos?.data?.statusMessage
    || conDatos?.statusMessage
    || conDatos?.message
    || t('comun.error')
}
</script>

<template>
  <UModal
    v-model:open="abierto"
    :title="esAlta ? $t('usuarios.nuevo') : $t('usuarios.editar')"
    :description="esAlta ? $t('usuarios.nuevoAyuda') : usuario?.email"
    :ui="{ content: 'max-w-2xl' }"
  >
    <template #body>
      <form
        id="form-usuario"
        v-auto-animate
        class="flex flex-col gap-4"
        @submit.prevent="guardar"
      >
        <UFormField :label="$t('usuarios.nombre')">
          <UInput
            v-model="nombre"
            required
            icon="i-lucide-user-round"
            class="w-full"
          />
        </UFormField>

        <UFormField
          :label="$t('usuarios.email')"
          :description="esAlta ? undefined : $t('usuarios.emailFijo')"
        >
          <UInput
            v-model="email"
            type="email"
            :disabled="!esAlta"
            required
            icon="i-lucide-mail"
            class="w-full"
          />
        </UFormField>

        <UFormField
          v-if="esAlta"
          :label="$t('usuarios.passwordInicial')"
          :description="$t('perfil.minimo', { min: 8 })"
        >
          <UInput
            v-model="password"
            type="password"
            autocomplete="new-password"
            required
            icon="i-lucide-key-round"
            class="w-full"
          />
        </UFormField>

        <!-- Alta: los roles del sistema, en selección múltiple -->
        <template v-if="esAlta">
          <UFormField
            :label="$t('usuarios.roles')"
            :description="$t('usuarios.rolesAyuda')"
          >
            <USelectMenu
              v-model="rolesElegidos"
              :items="opcionesRolSistema"
              value-key="value"
              multiple
              icon="i-lucide-users-round"
              :placeholder="$t('usuarios.rolesPlaceholder')"
              class="w-full"
            />
          </UFormField>

          <p
            v-if="esCore"
            class="rounded-lg bg-info/10 px-3 py-2 text-xs text-info"
          >
            {{ $t('usuarios.coreExcluye') }}
          </p>
        </template>

        <!-- Edición: rol global y estado -->
        <template v-if="!esAlta">
          <div class="flex flex-wrap gap-6 rounded-lg border border-default p-3">
            <USwitch
              v-model="esCore"
              :disabled="esRaiz"
              :label="$t('rol.morphos_core')"
              :description="$t('usuarios.excluyente')"
            />
            <USwitch
              v-model="activo"
              :disabled="esRaiz"
              :label="$t('usuarios.activo')"
            />
          </div>

          <p
            v-if="esRaiz"
            class="rounded-lg bg-info/10 px-3 py-2 text-xs text-info"
          >
            {{ $t('usuarios.raizProtegida') }}
          </p>
        </template>

        <!-- Pertenencias: aquí vive el rol por empresa, y su tarifa -->
        <div
          v-if="!esCore"
          class="flex flex-col gap-2"
        >
          <div class="flex items-center justify-between">
            <p class="text-sm font-medium">
              {{ $t('usuarios.pertenencias') }}
            </p>
            <UButton
              v-if="!esAlta"
              size="xs"
              variant="subtle"
              icon="i-lucide-plus"
              :disabled="!empresasLibres.length"
              :label="$t('usuarios.anadirEmpresa')"
              @click="anadirPertenencia"
            />
          </div>

          <p class="text-xs text-dimmed">
            {{ esAlta ? $t('usuarios.unaEmpresaPorRol') : $t('perfil.pertenenciasAyuda') }}
          </p>

          <div
            v-auto-animate
            class="flex flex-col gap-2"
          >
            <div
              v-for="(fila, i) in filas"
              :key="fila.id ?? `nueva-${fila.rol}-${i}`"
              class="grid grid-cols-1 items-end gap-2 rounded-lg border border-default p-2 sm:grid-cols-[1fr_1fr_auto_auto]"
            >
              <UFormField
                :label="$t('empresas.nombre')"
                size="xs"
              >
                <USelect
                  v-model="fila.empresa_id"
                  :items="opcionesEmpresa"
                  value-key="value"
                  :placeholder="$t('empresa.selecciona')"
                  class="w-full"
                />
              </UFormField>

              <UFormField
                :label="$t('usuarios.rolEnEmpresa')"
                size="xs"
              >
                <USelect
                  v-model="fila.rol"
                  :items="opcionesRol"
                  value-key="value"
                  :disabled="esAlta"
                  class="w-full"
                />
              </UFormField>

              <UFormField
                :label="$t('usuarios.tarifa')"
                size="xs"
              >
                <UInput
                  v-model.number="fila.tarifa_hora"
                  type="number"
                  step="0.01"
                  min="0"
                  class="w-24"
                />
              </UFormField>

              <UButton
                size="xs"
                color="error"
                variant="ghost"
                icon="i-lucide-trash-2"
                :title="$t('usuarios.quitarEmpresa')"
                @click="quitarPertenencia(i)"
              />
            </div>

            <p
              v-if="!filas.length"
              class="rounded-lg border border-dashed border-default px-3 py-4 text-center text-xs text-muted"
            >
              {{ esAlta ? $t('usuarios.sinRolesAun') : $t('usuarios.sinPertenencias') }}
            </p>
          </div>
        </div>

        <p
          v-if="error"
          class="rounded-lg bg-error/10 px-3 py-2 text-sm text-error"
        >
          {{ error }}
        </p>
      </form>
    </template>

    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton
          color="neutral"
          variant="ghost"
          :label="$t('comun.cancelar')"
          @click="close"
        />
        <UButton
          type="submit"
          form="form-usuario"
          :loading="guardando"
          :disabled="conflictoCore"
          :label="esAlta ? $t('comun.crear') : $t('comun.guardar')"
        />
      </div>
    </template>
  </UModal>
</template>
