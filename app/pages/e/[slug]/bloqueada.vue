<script setup lang="ts">
definePageMeta({ layout: 'blank', middleware: ['empresa'] })

const { empresa, slug, rol } = useEmpresaActiva()
const usuario = useMorphosUser()
const db = useDb()
const fecha = useFormatoFecha()
const { t } = useI18n()

useHead({ title: () => t('bloqueo.titulo') })

const { data: membresia } = await useAsyncData(
  () => `membresia:${empresa.value?.id}`,
  async () => {
    if (!empresa.value?.id) return null
    const { data } = await db
      .from('membresias')
      .select('vence_el')
      .eq('empresa_id', empresa.value.id)
      .maybeSingle()
    return data
  },
  { watch: [empresa] },
)

const enviando = ref(false)
const enviado = ref(false)

/**
 * La única vía de contacto no puede estar detrás del bloqueo que se reclama:
 * desde aquí se abre una incidencia de prioridad alta sin entrar al sistema
 * (docs/spec/30-comercial.md §3.1).
 */
async function reportarProblema() {
  if (!empresa.value?.id || !usuario.value?.id) return
  enviando.value = true

  await db.from('incidencias').insert({
    empresa_id: empresa.value.id,
    abierta_por: usuario.value.id,
    asunto: t('bloqueo.problema'),
    tipo: 'pago',
    prioridad: 'alta',
  })

  enviando.value = false
  enviado.value = true
}
</script>

<template>
  <div class="w-full max-w-md text-center">
    <UIcon
      name="i-lucide-lock"
      class="mx-auto size-10 text-warning"
    />

    <h1 class="mt-4 text-xl font-semibold">
      {{ $t('bloqueo.titulo') }}
    </h1>

    <p class="mt-2 text-sm text-muted">
      {{ $t('bloqueo.descripcion', {
        empresa: empresa?.nombre ?? '',
        fecha: fecha(membresia?.vence_el ?? null),
      }) }}
    </p>

    <div
      v-auto-animate
      class="mt-6 flex flex-col gap-2"
    >
      <UButton
        v-if="rol === 'owner'"
        block
        icon="i-lucide-credit-card"
        :label="$t('bloqueo.pagar')"
      />

      <UButton
        v-if="!enviado"
        block
        color="neutral"
        variant="subtle"
        icon="i-lucide-life-buoy"
        :loading="enviando"
        :label="$t('bloqueo.problema')"
        @click="reportarProblema"
      />

      <p
        v-else
        class="rounded-lg bg-success/10 px-3 py-2 text-sm text-success"
      >
        {{ $t('bloqueo.problemaEnviado') }}
      </p>

      <!-- Trabajador, vendedor y afiliado conservan la lectura de su saldo. -->
      <UButton
        v-if="rol && !['owner', 'administrador'].includes(rol)"
        block
        color="neutral"
        variant="ghost"
        icon="i-lucide-wallet"
        :to="`/e/${slug}/saldo`"
        :label="$t('saldo.titulo')"
      />

      <UButton
        block
        color="neutral"
        variant="ghost"
        size="sm"
        to="/empresas"
        :label="$t('nav.cambiarEmpresa')"
      />
    </div>
  </div>
</template>
