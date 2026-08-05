<script setup lang="ts">
import type { CompanyOverview } from '~/composables/useMorphosCore'

// Panel de sistema, exclusivo de morphos_core (§3.1). `roles` queda vacio a
// proposito: los roles de definePageMeta son roles de empresa, y morphos_core
// no tiene ninguno. El filtro real es la comprobacion de abajo, y por debajo
// la RLS, que a cualquier otro rol solo le devolveria su propia empresa.
definePageMeta({ middleware: 'require-role' })

const { t } = useI18n()
const localePath = useLocalePath()
const { isMorphosCore, switchCompany } = useAppUser()
const { companies, totals, pending, errorMessage, fetchCompanies, setSupervision } = useMorphosCore()

if (!isMorphosCore.value) {
  await navigateTo(localePath('/dashboard'))
}

await fetchCompanies()

const money = new Intl.NumberFormat('es', { style: 'currency', currency: 'USD' })

/** Entrar a gestionar una empresa concreta reutiliza las pantallas normales. */
async function manage(company: CompanyOverview) {
  if (!company.company_id) return
  switchCompany(company.company_id)
  await navigateTo(localePath('/equipo'))
}

useSeoMeta({ title: () => `${t('morphos.title')} · ${t('app.name')}` })
</script>

<template>
  <UContainer class="py-12 space-y-6">
    <div class="space-y-1">
      <div class="flex items-center gap-2">
        <UIcon
          name="i-lucide-shield"
          class="size-5 text-primary"
        />
        <h1 class="text-2xl font-semibold">
          {{ $t('morphos.title') }}
        </h1>
      </div>
      <p class="text-sm text-muted">
        {{ $t('morphos.description') }}
      </p>
    </div>

    <UAlert
      v-if="errorMessage"
      icon="i-lucide-triangle-alert"
      color="error"
      variant="subtle"
      :description="errorMessage"
    />

    <!-- Resumen del sistema entero -->
    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <UCard
        v-for="stat in [
          { key: 'companies', value: totals.companies },
          { key: 'members', value: totals.members },
          { key: 'workSites', value: totals.workSites },
          { key: 'pendingEntries', value: totals.pendingEntries }
        ]"
        :key="stat.key"
      >
        <p class="text-sm text-muted">
          {{ $t(`morphos.stats.${stat.key}`) }}
        </p>
        <p class="text-2xl font-semibold tabular-nums">
          {{ stat.value }}
        </p>
      </UCard>
    </div>

    <div class="grid gap-4 sm:grid-cols-2">
      <UCard>
        <p class="text-sm text-muted">
          {{ $t('morphos.stats.weekIncome') }}
        </p>
        <p class="text-2xl font-semibold tabular-nums">
          {{ money.format(totals.weekIncome) }}
        </p>
      </UCard>

      <UCard>
        <p class="text-sm text-muted">
          {{ $t('morphos.stats.supervised') }}
        </p>
        <p class="text-2xl font-semibold tabular-nums">
          {{ totals.supervised }} / {{ totals.companies }}
        </p>
      </UCard>
    </div>

    <!-- Empresas del sistema -->
    <UCard>
      <template #header>
        <h2 class="font-semibold">
          {{ $t('morphos.companies') }}
        </h2>
      </template>

      <p
        v-if="pending && !companies.length"
        class="py-8 text-center text-sm text-muted"
      >
        {{ $t('morphos.loading') }}
      </p>

      <p
        v-else-if="!companies.length"
        class="py-8 text-center text-sm text-muted"
      >
        {{ $t('morphos.empty') }}
      </p>

      <ul
        v-else
        v-auto-animate
        class="divide-y divide-default"
      >
        <li
          v-for="company in companies"
          :key="company.company_id ?? ''"
          class="py-3 flex flex-wrap items-center gap-3"
        >
          <div class="flex-1 min-w-52">
            <p class="font-medium">
              {{ company.name }}
            </p>
            <p class="text-sm text-muted">
              {{ company.jurisdiction }} ·
              {{ $t('morphos.membersCount', { n: company.active_members ?? 0 }) }} ·
              {{ $t('morphos.sitesCount', { n: company.active_work_sites ?? 0 }) }}
            </p>
          </div>

          <span class="text-sm tabular-nums">
            {{ money.format(Number(company.week_income ?? 0)) }}
          </span>

          <UBadge
            v-if="company.pending_entries"
            color="warning"
            variant="subtle"
          >
            {{ $t('morphos.pending', { n: company.pending_entries }) }}
          </UBadge>

          <!-- Sin reglas de compliance cargadas la empresa opera igual, pero no
               recibe alertas: es una tarea del equipo interno, no un bloqueo. -->
          <UBadge
            v-if="company.compliance_pending"
            color="neutral"
            variant="outline"
          >
            {{ $t('morphos.compliancePending') }}
          </UBadge>

          <UBadge
            v-if="company.supervision_contracted"
            color="primary"
            variant="subtle"
          >
            {{ $t('morphos.supervised') }}
          </UBadge>

          <div class="flex gap-2">
            <UButton
              size="xs"
              color="neutral"
              variant="subtle"
              :label="company.supervision_contracted
                ? $t('morphos.cancelSupervision')
                : $t('morphos.contractSupervision')"
              @click="setSupervision(company.company_id!, !company.supervision_contracted)"
            />

            <UButton
              size="xs"
              color="neutral"
              variant="ghost"
              icon="i-lucide-arrow-right"
              :label="$t('morphos.manage')"
              @click="manage(company)"
            />
          </div>
        </li>
      </ul>
    </UCard>

    <p class="text-xs text-muted">
      {{ $t('morphos.supervisionNote') }}
    </p>
  </UContainer>
</template>
