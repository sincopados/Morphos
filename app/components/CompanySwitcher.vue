<script setup lang="ts">
/**
 * Selector de empresa activa (§2.1). Solo aparece cuando la persona pertenece
 * a mas de una: con una sola no hay nada que elegir.
 *
 * Cambiar de empresa cambia el rol, porque el rol es de la pertenencia: quien
 * es `owner` aqui puede ser `trabajador` alla.
 */
const { memberships, activeCompanyId, hasSeveralCompanies, switchCompany } = useAppUser()

const items = computed(() =>
  memberships.value.map(m => ({
    value: m.company_id,
    label: m.companies?.name ?? '—',
    role: m.role
  }))
)
</script>

<template>
  <USelectMenu
    v-if="hasSeveralCompanies"
    :model-value="activeCompanyId ?? undefined"
    :items="items"
    value-key="value"
    label-key="label"
    icon="i-lucide-building-2"
    @update:model-value="(id: string) => switchCompany(id)"
  >
    <template #item-trailing="{ item }">
      <span class="text-xs text-muted">{{ $t(`roles.${item.role}`) }}</span>
    </template>
  </USelectMenu>
</template>
