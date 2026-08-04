<script setup lang="ts">
const { t } = useI18n()

// `seo: true` agrega tambien los canonical y hreflang absolutos, que dependen
// del baseUrl configurado en nuxt.config.
const i18nHead = useLocaleHead({ seo: true })

useHead(() => ({
  htmlAttrs: i18nHead.value.htmlAttrs,
  link: [
    { rel: 'icon', href: '/favicon.ico' },
    ...i18nHead.value.link ?? []
  ],
  meta: [
    { name: 'viewport', content: 'width=device-width, initial-scale=1' },
    ...i18nHead.value.meta ?? []
  ]
}))

useSeoMeta({
  title: () => t('home.title'),
  description: () => t('home.description'),
  ogTitle: () => t('home.title'),
  ogDescription: () => t('home.description'),
  twitterCard: 'summary_large_image'
})
</script>

<template>
  <UApp>
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>
