<script setup lang="ts">
const usuario = useMorphosUser()
const esCore = useEsMorphosCore()
const { empresa, slug } = useEmpresaActiva()
const pertenencias = usePertenencias()
const authId = useAuthUserId()
const supabase = useSupabaseClient()
const db = useDb()
const { t } = useI18n()

// morphos_core no tiene empresa, así que conserva su barra lateral del
// Dashboard Global; el resto entra desde su empresa.
definePageMeta({ layout: false })
setPageLayout(esCore.value ? 'global' : 'default')

useHead({ title: () => t('perfil.titulo') })

// --- Datos personales -------------------------------------------------------

const nombre = ref(usuario.value?.nombre ?? '')
const avatarUrl = ref(usuario.value?.avatar_url ?? '')
const guardandoDatos = ref(false)
const errorDatos = ref('')
const okDatos = ref(false)

async function guardarDatos() {
  if (!authId.value || !nombre.value.trim()) return
  guardandoDatos.value = true
  errorDatos.value = ''
  okDatos.value = false

  const { data, error } = await db
    .from('usuarios')
    .update({
      nombre: nombre.value.trim(),
      avatar_url: avatarUrl.value.trim() || null,
    })
    .eq('id', authId.value)
    .select()
    .single()

  guardandoDatos.value = false

  if (error) {
    errorDatos.value = error.message
    return
  }

  // Refresca el estado compartido para que la cabecera cambie al instante.
  if (data) usuario.value = data
  okDatos.value = true
}

// --- Contraseña -------------------------------------------------------------

const actual = ref('')
const nueva = ref('')
const repetida = ref('')
const guardandoPass = ref(false)
const errorPass = ref('')
const okPass = ref(false)

const MIN = 8

async function cambiarPassword() {
  errorPass.value = ''
  okPass.value = false

  if (nueva.value.length < MIN) {
    errorPass.value = t('perfil.errorCorta', { min: MIN })
    return
  }
  if (nueva.value !== repetida.value) {
    errorPass.value = t('perfil.errorNoCoincide')
    return
  }
  if (!usuario.value?.email) return

  guardandoPass.value = true

  // Supabase permite cambiar la contraseña con solo la sesión abierta. Pedimos
  // la actual y la comprobamos primero: si alguien se sienta ante una sesión
  // abierta, no debería poder quedarse con la cuenta.
  const { error: errVerif } = await supabase.auth.signInWithPassword({
    email: usuario.value.email,
    password: actual.value,
  })

  if (errVerif) {
    guardandoPass.value = false
    errorPass.value = t('perfil.errorActual')
    return
  }

  const { error } = await supabase.auth.updateUser({ password: nueva.value })

  guardandoPass.value = false

  if (error) {
    errorPass.value = error.message
    return
  }

  actual.value = ''
  nueva.value = ''
  repetida.value = ''
  okPass.value = true
}

const volverA = computed(() => (esCore.value ? '/global' : slug.value ? `/e/${slug.value}` : '/empresas'))
</script>

<template>
  <div class="mx-auto flex max-w-2xl flex-col gap-6">
    <AppHeader
      :titulo="$t('perfil.titulo')"
      :subtitulo="usuario?.email"
    >
      <template #acciones>
        <UButton
          size="sm"
          color="neutral"
          variant="ghost"
          icon="i-lucide-arrow-left"
          :to="volverA"
          :label="$t('comun.volver')"
        />
      </template>
    </AppHeader>

    <!-- Datos personales -->
    <UCard>
      <template #header>
        <h2 class="font-medium">
          {{ $t('perfil.datos') }}
        </h2>
      </template>

      <form
        v-auto-animate
        class="flex flex-col gap-4"
        @submit.prevent="guardarDatos"
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
          :label="$t('perfil.avatar')"
          :description="$t('perfil.avatarAyuda')"
        >
          <UInput
            v-model="avatarUrl"
            type="url"
            placeholder="https://…"
            icon="i-lucide-image"
            class="w-full"
          />
        </UFormField>

        <UFormField
          :label="$t('usuarios.email')"
          :description="$t('perfil.emailBloqueado')"
        >
          <UInput
            :model-value="usuario?.email"
            disabled
            icon="i-lucide-mail"
            class="w-full"
          />
        </UFormField>

        <p
          v-if="errorDatos"
          class="rounded-lg bg-error/10 px-3 py-2 text-sm text-error"
        >
          {{ errorDatos }}
        </p>
        <p
          v-if="okDatos"
          class="rounded-lg bg-success/10 px-3 py-2 text-sm text-success"
        >
          {{ $t('perfil.guardado') }}
        </p>

        <div>
          <UButton
            type="submit"
            :loading="guardandoDatos"
            :label="$t('comun.guardar')"
          />
        </div>
      </form>
    </UCard>

    <!-- Contraseña -->
    <UCard>
      <template #header>
        <h2 class="font-medium">
          {{ $t('perfil.password') }}
        </h2>
      </template>

      <form
        v-auto-animate
        class="flex flex-col gap-4"
        @submit.prevent="cambiarPassword"
      >
        <UFormField :label="$t('perfil.actual')">
          <UInput
            v-model="actual"
            type="password"
            autocomplete="current-password"
            required
            icon="i-lucide-lock"
            class="w-full"
          />
        </UFormField>

        <UFormField
          :label="$t('perfil.nueva')"
          :description="$t('perfil.minimo', { min: MIN })"
        >
          <UInput
            v-model="nueva"
            type="password"
            autocomplete="new-password"
            required
            icon="i-lucide-key-round"
            class="w-full"
          />
        </UFormField>

        <UFormField :label="$t('perfil.repetir')">
          <UInput
            v-model="repetida"
            type="password"
            autocomplete="new-password"
            required
            icon="i-lucide-key-round"
            class="w-full"
          />
        </UFormField>

        <p
          v-if="errorPass"
          class="rounded-lg bg-error/10 px-3 py-2 text-sm text-error"
        >
          {{ errorPass }}
        </p>
        <p
          v-if="okPass"
          class="rounded-lg bg-success/10 px-3 py-2 text-sm text-success"
        >
          {{ $t('perfil.passwordCambiada') }}
        </p>

        <div>
          <UButton
            type="submit"
            :loading="guardandoPass"
            :label="$t('perfil.cambiarPassword')"
          />
        </div>
      </form>
    </UCard>

    <!-- Apariencia -->
    <UCard>
      <template #header>
        <h2 class="font-medium">
          {{ $t('tema.titulo') }}
        </h2>
      </template>
      <ThemeSwitcher />
    </UCard>

    <!-- Pertenencias: rol, tarifa y saldo son de cada una, no de la persona -->
    <UCard v-if="!esCore">
      <template #header>
        <div>
          <h2 class="font-medium">
            {{ $t('usuarios.pertenencias') }}
          </h2>
          <p class="mt-1 text-xs text-dimmed">
            {{ $t('perfil.pertenenciasAyuda') }}
          </p>
        </div>
      </template>

      <ul
        v-auto-animate
        class="divide-y divide-default/60 text-sm"
      >
        <li
          v-for="p in pertenencias"
          :key="p.id"
          class="flex items-center justify-between gap-3 py-2"
        >
          <div>
            <p :class="{ 'text-primary': p.empresa_id === empresa?.id }">
              {{ p.empresas?.nombre }}
            </p>
            <p class="text-xs text-dimmed">
              {{ $t(`rol.${p.rol}`) }}
            </p>
          </div>
          <EstadoBadge
            v-if="p.empresas"
            :estado="p.empresas.estado"
          />
        </li>
      </ul>
    </UCard>

    <UCard v-else>
      <div class="flex items-center gap-3 text-sm text-muted">
        <UIcon
          name="i-lucide-shield"
          class="size-5 shrink-0 text-primary"
        />
        <p>{{ $t('perfil.coreSinEmpresas') }}</p>
      </div>
    </UCard>
  </div>
</template>
