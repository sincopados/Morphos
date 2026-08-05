import {
  serverSupabaseClient,
  serverSupabaseServiceRole,
  serverSupabaseUser,
} from '#supabase/server'

/**
 * Alta de usuario desde el Dashboard Global.
 *
 * Crear una cuenta exige la clave de servicio, que nunca puede salir al
 * navegador: por eso vive aquí y no en la página. La comprobación de rol
 * también se hace aquí — el cliente puede mentir sobre quién dice ser.
 */
export default defineEventHandler(async (event) => {
  const claims = await serverSupabaseUser(event)
  if (!claims?.sub) {
    throw createError({ statusCode: 401, statusMessage: 'No autenticado' })
  }

  // El rol se comprueba con el cliente del propio solicitante, no con el de
  // servicio: así el guard funciona aunque falte la clave de servicio, y quien
  // no es del equipo recibe 404 antes de enterarse de nada más.
  const db = await serverSupabaseClient(event)
  const { data: quien } = await db
    .from('usuarios')
    .select('rol_global, activo')
    .eq('id', claims.sub)
    .maybeSingle()

  if (quien?.rol_global !== 'morphos_core' || !quien.activo) {
    // 404 y no 403: el Dashboard Global no existe para quien no es del equipo.
    throw createError({ statusCode: 404, statusMessage: 'Not Found' })
  }

  const body = await readBody<{
    email?: string
    password?: string
    nombre?: string
  }>(event)

  const email = body.email?.trim().toLowerCase()
  const password = body.password ?? ''
  const nombre = body.nombre?.trim()

  if (!email || !email.includes('@')) {
    throw createError({ statusCode: 400, statusMessage: 'Correo no válido' })
  }
  if (password.length < 8) {
    throw createError({ statusCode: 400, statusMessage: 'La contraseña debe tener al menos 8 caracteres' })
  }
  if (!nombre) {
    throw createError({ statusCode: 400, statusMessage: 'El nombre es obligatorio' })
  }

  // Sin clave de servicio no se puede crear una cuenta. El error del módulo es
  // críptico, así que damos uno accionable.
  const config = useRuntimeConfig(event)
  if (!config.supabase.serviceKey && !config.supabase.secretKey) {
    throw createError({
      statusCode: 501,
      statusMessage: 'Falta SUPABASE_SERVICE_KEY en el entorno: sin ella no se pueden crear cuentas.',
    })
  }

  const admin = serverSupabaseServiceRole(event)

  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: nombre },
  })

  if (error) {
    throw createError({ statusCode: 400, statusMessage: error.message })
  }

  // El trigger on_auth_user_created ya insertó la fila en `usuarios` tomando
  // el nombre de user_metadata; esto solo lo asegura.
  if (data.user) {
    const { error: errNombre } = await admin
      .from('usuarios')
      .update({ nombre })
      .eq('id', data.user.id)

    // La cuenta ya está creada, así que no se aborta; pero tampoco se calla,
    // porque un fallo aquí significa que algo va mal con los permisos.
    if (errNombre) {
      console.warn('[morphos] no se pudo fijar el nombre del usuario:', errNombre.message)
    }
  }

  return { id: data.user?.id, email }
})
