/**
 * El Dashboard Global es exclusivo de `morphos_core`. Nadie más lo ve en el
 * menú ni lo alcanza por URL directa (docs/spec/40-dashboard-global.md).
 */
export default defineNuxtRouteMiddleware(() => {
  const esCore = useEsMorphosCore()

  if (!esCore.value) {
    throw createError({ statusCode: 404, statusMessage: 'Not Found' })
  }
})
