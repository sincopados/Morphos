<script setup lang="ts">
const localePath = useLocalePath()
const user = useSupabaseUser()
const { signOut } = useAuthActions()
</script>

<template>
  <div>
    <UHeader>
      <template #left>
        <NuxtLink :to="localePath('/')">
          <AppLogo class="w-auto h-6 shrink-0" />
        </NuxtLink>
      </template>

      <template #right>
        <LocaleToggle />

        <UColorModeButton />

        <UButton
          v-if="user"
          :label="$t('auth.signOut')"
          color="neutral"
          variant="ghost"
          @click="signOut"
        />
        <UButton
          v-else
          :to="localePath('/login')"
          :label="$t('auth.login.submit')"
          color="neutral"
          variant="subtle"
        />
      </template>
    </UHeader>

    <UMain>
      <slot />
    </UMain>

    <USeparator />

    <UFooter>
      <template #left>
        <p class="text-sm text-muted">
          {{ $t('app.name') }} • © {{ new Date().getFullYear() }}
        </p>
      </template>
    </UFooter>
  </div>
</template>
