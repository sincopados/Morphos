<script setup lang="ts">
import { z } from 'zod'
import { INVITABLE_ROLES } from '~/composables/useAppUser'
import type { InviteInput, TeamMember } from '~/composables/useTeam'

// El middleware solo decide la navegacion; quien manda es la RLS. El rol se
// evalua sobre la empresa activa (§2.1).
definePageMeta({
  middleware: 'require-role',
  roles: ['owner', 'administrador']
})

const { t } = useI18n()
const { isOwner, isMorphosCore, company } = useAppUser()

// morphos_core gestiona cualquier empresa sin pertenecer a ella (§3.1), asi que
// tiene los mismos controles que el owner de la empresa que este supervisando.
const canManageTeam = computed(() => isOwner.value || isMorphosCore.value)
const {
  members, workSites, adminSites, pending, errorMessage,
  fetchTeam, invite, setStatus, unblockCheckin, assignWorkSites
} = useTeam()

await fetchTeam()

const inviteOpen = ref(false)

const roleOptions = computed(() =>
  INVITABLE_ROLES.map(value => ({ value, label: t(`roles.${value}`) }))
)

const schema = computed(() => z.object({
  fullName: z.string().min(2, t('team.validation.fullName')),
  email: z.string().email(t('auth.validation.email')),
  role: z.enum(INVITABLE_ROLES)
}))

const state = reactive<InviteInput>({
  fullName: '',
  email: '',
  role: 'trabajador'
})

async function onInvite() {
  if (await invite(state)) {
    inviteOpen.value = false
    Object.assign(state, { fullName: '', email: '', role: 'trabajador' })
  }
}

/** Un administrador sin obras asignadas no alcanza nada todavia (§5.10). */
function sitesOf(member: TeamMember): string {
  const ids = adminSites.value[member.id] ?? []

  if (!ids.length) {
    return t('team.noSites')
  }

  return workSites.value
    .filter(site => ids.includes(site.id))
    .map(site => site.name)
    .join(', ')
}

useSeoMeta({ title: () => `${t('team.title')} · ${t('app.name')}` })
</script>

<template>
  <UContainer class="py-12 space-y-6">
    <div class="flex items-start justify-between gap-4">
      <div class="space-y-1">
        <h1 class="text-2xl font-semibold">
          {{ $t('team.title') }}
        </h1>
        <p class="text-sm text-muted">
          {{ $t('team.description', { company: company?.name ?? '' }) }}
        </p>
      </div>

      <div class="flex items-center gap-2">
        <CompanySwitcher />

        <UButton
          v-if="canManageTeam"
          icon="i-lucide-user-plus"
          :label="$t('team.invite')"
          @click="inviteOpen = true"
        />
      </div>
    </div>

    <UAlert
      v-if="errorMessage"
      icon="i-lucide-triangle-alert"
      color="error"
      variant="subtle"
      :description="errorMessage"
    />

    <UCard>
      <div
        v-if="pending && !members.length"
        class="py-8 text-center text-sm text-muted"
      >
        {{ $t('team.loading') }}
      </div>

      <ul
        v-else
        v-auto-animate
        class="divide-y divide-default"
      >
        <li
          v-for="member in members"
          :key="member.id"
          class="py-3 flex flex-wrap items-center gap-3"
        >
          <div class="flex-1 min-w-48">
            <p class="font-medium">
              {{ member.profiles?.full_name ?? '—' }}
            </p>
            <p class="text-sm text-muted">
              {{ member.profiles?.email ?? $t('team.noEmail') }}
            </p>
          </div>

          <UBadge
            variant="subtle"
            :color="member.role === 'owner' ? 'primary' : 'neutral'"
          >
            {{ $t(`roles.${member.role}`) }}
          </UBadge>

          <!-- Solo el administrador tiene obras asignadas: el owner las alcanza
               todas y el resto de roles no gestiona ninguna. -->
          <span
            v-if="member.role === 'administrador'"
            class="text-sm text-muted"
          >
            {{ sitesOf(member) }}
          </span>

          <UBadge
            v-if="member.checkin_blocked"
            color="error"
            variant="subtle"
          >
            {{ $t('team.blocked') }}
          </UBadge>

          <UBadge
            v-if="member.status === 'inactivo'"
            color="neutral"
            variant="outline"
          >
            {{ $t('team.inactive') }}
          </UBadge>

          <!-- Sin auth_user_id la persona todavia no entro nunca: la
               invitacion se reclama sola al iniciar sesion con ese correo. -->
          <UBadge
            v-else-if="!member.profiles?.auth_user_id"
            color="warning"
            variant="subtle"
          >
            {{ $t('team.pendingInvite') }}
          </UBadge>

          <div class="flex gap-2">
            <UButton
              v-if="member.checkin_blocked"
              size="xs"
              color="neutral"
              variant="subtle"
              :label="$t('team.unblock')"
              @click="unblockCheckin(member.id)"
            />

            <UButton
              v-if="canManageTeam && member.role !== 'owner'"
              size="xs"
              color="neutral"
              variant="ghost"
              :label="member.status === 'activo' ? $t('team.deactivate') : $t('team.activate')"
              @click="setStatus(member.id, member.status === 'activo' ? 'inactivo' : 'activo')"
            />

            <USelectMenu
              v-if="canManageTeam && member.role === 'administrador'"
              :model-value="adminSites[member.id] ?? []"
              :items="workSites"
              value-key="id"
              label-key="name"
              multiple
              size="xs"
              :placeholder="$t('team.assignSites')"
              @update:model-value="(ids: string[]) => assignWorkSites(member.id, ids)"
            />
          </div>
        </li>
      </ul>
    </UCard>

    <UModal
      v-model:open="inviteOpen"
      :title="$t('team.invite')"
      :description="$t('team.inviteDescription')"
    >
      <template #body>
        <UForm
          :schema="schema"
          :state="state"
          class="space-y-4"
          @submit="onInvite"
        >
          <UFormField
            name="fullName"
            :label="$t('team.fields.fullName')"
            required
          >
            <UInput
              v-model="state.fullName"
              class="w-full"
            />
          </UFormField>

          <UFormField
            name="email"
            :label="$t('auth.fields.email')"
            required
            :hint="$t('team.fields.emailHint')"
          >
            <UInput
              v-model="state.email"
              type="email"
              class="w-full"
            />
          </UFormField>

          <UFormField
            name="role"
            :label="$t('team.fields.role')"
            required
          >
            <USelectMenu
              v-model="state.role"
              :items="roleOptions"
              value-key="value"
              label-key="label"
              class="w-full"
            />
          </UFormField>

          <UButton
            type="submit"
            :label="$t('team.invite')"
            block
            :loading="pending"
          />
        </UForm>
      </template>
    </UModal>
  </UContainer>
</template>
