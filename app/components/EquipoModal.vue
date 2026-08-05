<script setup lang="ts">
import type { MiembroEquipo } from '~/composables/useMorphos'
import type { UserRole } from '#shared/types/database'

const props = defineProps<{
  /** `null` abre el modal en modo alta. */
  miembro: MiembroEquipo | null
  empresaId: string
}>()

const emit = defineEmits<{ guardado: [] }>()

const abierto = defineModel<boolean>('open', { default: false })

const db = useDb()
const { t } = useI18n()

const esAlta = computed(() => props.miembro === null)
const guardando = ref(false)
const error = ref('')

const nombre = ref('')
const email = ref('')
const password = ref('')
const rol = ref<UserRole>('trabajador')
const tarifa = ref(0)

/**
 * El owner gestiona su equipo, no la propiedad de la empresa: dar de alta a
 * otro `owner` es un cambio de titularidad, no una contratación, y se hace
 * desde el Dashboard Global.
 */
const rolesDisponibles: UserRole[] = ['administrador', 'trabajador', 'vendedor', 'afiliado']

const opcionesRol = computed(() =>
  rolesDisponibles.map(r => ({ label: t(`rol.${r}`), value: r })),
)

watch(abierto, (v) => {
  if (!v) return
  error.value = ''
  password.value = ''

  const m = props.miembro
  nombre.value = m?.usuarios?.nombre ?? ''
  email.value = m?.usuarios?.email ?? ''
  rol.value = m?.rol ?? 'trabajador'
  tarifa.value = Number(m?.tarifa_hora ?? 0)
}, { immediate: true })

async function guardar() {
  error.value = ''

  if (!nombre.value.trim()) {
    error.value = t('usuarios.errorNombre')
    return
  }

  guardando.value = true

  try {
    if (esAlta.value) {
      await $fetch(`/api/empresas/${props.empresaId}/equipo`, {
        method: 'POST',
        body: {
          email: email.value,
          nombre: nombre.value.trim(),
          password: password.value,
          rol: rol.value,
          tarifa_hora: Number(tarifa.value) || 0,
        },
      })
    }
    else {
      // Solo se toca la pertenencia. El nombre y el correo son de la persona,
      // no de la empresa, y RLS impide que el owner los cambie.
      const { error: err } = await db
        .from('pertenencias')
        .update({
          rol: rol.value,
          perfil: rol.value === 'trabajador' ? 'con_horario' : 'sin_horario',
          tarifa_hora: Number(tarifa.value) || 0,
        })
        .eq('id', props.miembro!.id)

      if (err) throw new Error(err.message)
    }

    emit('guardado')
    abierto.value = false
  }
  catch (e) {
    const d = e as { statusMessage?: string, data?: { statusMessage?: string }, message?: string }
    error.value = d?.data?.statusMessage || d?.statusMessage || d?.message || t('comun.error')
  }
  finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal
    v-model:open="abierto"
    :title="esAlta ? $t('equipo.nuevo') : $t('equipo.editar')"
    :description="esAlta ? $t('equipo.nuevoAyuda') : miembro?.usuarios?.email"
  >
    <template #body>
      <form
        id="form-equipo"
        v-auto-animate
        class="flex flex-col gap-4"
        @submit.prevent="guardar"
      >
        <UFormField :label="$t('usuarios.nombre')">
          <UInput
            v-model="nombre"
            required
            :disabled="!esAlta"
            icon="i-lucide-user-round"
            class="w-full"
          />
        </UFormField>

        <UFormField
          :label="$t('usuarios.email')"
          :description="esAlta ? $t('equipo.emailExistente') : $t('equipo.datosDeLaPersona')"
        >
          <UInput
            v-model="email"
            type="email"
            required
            :disabled="!esAlta"
            icon="i-lucide-mail"
            class="w-full"
          />
        </UFormField>

        <UFormField
          v-if="esAlta"
          :label="$t('usuarios.passwordInicial')"
          :description="$t('equipo.passwordAyuda')"
        >
          <UInput
            v-model="password"
            type="password"
            autocomplete="new-password"
            icon="i-lucide-key-round"
            class="w-full"
          />
        </UFormField>

        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField :label="$t('usuarios.rolEnEmpresa')">
            <USelect
              v-model="rol"
              :items="opcionesRol"
              value-key="value"
              class="w-full"
            />
          </UFormField>

          <UFormField
            :label="$t('usuarios.tarifa')"
            :description="$t('equipo.tarifaAyuda')"
          >
            <UInput
              v-model.number="tarifa"
              type="number"
              step="0.01"
              min="0"
              class="w-full"
            />
          </UFormField>
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
          form="form-equipo"
          :loading="guardando"
          :label="esAlta ? $t('comun.crear') : $t('comun.guardar')"
        />
      </div>
    </template>
  </UModal>
</template>
