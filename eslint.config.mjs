// @ts-check
import withNuxt from './.nuxt/eslint.config.mjs'

export default withNuxt(
  {
    // database.types.ts lo genera Supabase — no lo formateamos a mano.
    ignores: ['.agents/**', '.claude/**', 'app/types/database.types.ts']
  }
)
