<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const pertenencias = usePertenencias()
const esCore = useEsMorphosCore()
const { t } = useI18n()

// morphos_core no pertenece a ninguna empresa (ADR-0002): el selector no le
// diría nada, su sitio es el Dashboard Global.
if (esCore.value) {
  await navigateTo('/global')
}

useHead({ title: () => t('empresa.selecciona') })
</script>

<template>
  <div class="w-full max-w-2xl">
    <h1 class="mb-1 text-xl font-semibold">
      {{ $t('empresa.selecciona') }}
    </h1>
    <p class="mb-6 text-sm text-muted">
      {{ $t('saldo.explicacion') }}
    </p>

    <div
      v-auto-animate
      class="grid gap-3 sm:grid-cols-2"
    >
      <NuxtLink
        v-for="p in pertenencias"
        :key="p.id"
        :to="`/e/${p.empresas?.slug}`"
        class="rounded-xl border border-default p-4 transition-colors hover:border-primary/60 hover:bg-elevated/40"
      >
        <div class="flex items-start justify-between gap-2">
          <p class="font-medium">
            {{ p.empresas?.nombre }}
          </p>
          <EstadoBadge
            v-if="p.empresas"
            :estado="p.empresas.estado"
          />
        </div>
        <p class="mt-2 text-xs text-dimmed">
          {{ $t(`rol.${p.rol}`) }} · {{ p.empresas?.jurisdiccion }}
        </p>
      </NuxtLink>
    </div>

    <p
      v-if="!pertenencias.length"
      class="rounded-xl border border-dashed border-default p-8 text-center text-sm text-muted"
    >
      {{ $t('empresa.sinEmpresas') }}
    </p>

    <div class="mt-6 flex justify-center">
      <LocaleSwitcher />
    </div>
  </div>
</template>
