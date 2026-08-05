import {
  serverSupabaseClient,
  serverSupabaseServiceRole,
  serverSupabaseUser,
} from '#supabase/server'

/** El owner gestiona su equipo, no la propiedad de la empresa. */
const ROLES_PERMITIDOS = ['administrador', 'trabajador', 'vendedor', 'afiliado'] as const
type RolPermitido = typeof ROLES_PERMITIDOS[number]

/**
 * Alta de una persona en el equipo de una empresa, hecha por su `owner`.
 *
 * Crear la cuenta exige la clave de servicio, que no puede salir al navegador.
 * La pertenencia, en cambio, se inserta con el cliente de quien llama: así RLS
 * sigue siendo la autoridad final aunque esta comprobación fallara.
 */
export default defineEventHandler(async (event) => {
  const claims = await serverSupabaseUser(event)
  if (!claims?.sub) {
    throw createError({ statusCode: 401, statusMessage: 'No autenticado' })
  }

  const empresaId = getRouterParam(event, 'empresa')
  if (!empresaId) {
    throw createError({ statusCode: 400, statusMessage: 'Falta la empresa' })
  }

  const db = await serverSupabaseClient(event)

  // Solo el `owner` de ESTA empresa. `morphos_core` entra por el Dashboard
  // Global, que tiene su propia ruta de alta.
  const { data: mia } = await db
    .from('pertenencias')
    .select('rol')
    .eq('empresa_id', empresaId)
    .eq('usuario_id', claims.sub)
    .eq('activa', true)
    .maybeSingle()

  if (mia?.rol !== 'owner') {
    throw createError({ statusCode: 404, statusMessage: 'Not Found' })
  }

  const { data: empresa } = await db
    .from('empresas')
    .select('estado')
    .eq('id', empresaId)
    .maybeSingle()

  // Con la empresa bloqueada nadie escribe (ADR-0001).
  if (empresa?.estado !== 'activa') {
    throw createError({ statusCode: 409, statusMessage: 'La empresa no está activa' })
  }

  const body = await readBody<{
    email?: string
    nombre?: string
    password?: string
    rol?: string
    tarifa_hora?: number
  }>(event)

  const email = body.email?.trim().toLowerCase()
  const nombre = body.nombre?.trim()
  const password = body.password ?? ''
  const rol = body.rol as RolPermitido | undefined

  if (!email || !email.includes('@')) {
    throw createError({ statusCode: 400, statusMessage: 'Correo no válido' })
  }
  if (!nombre) {
    throw createError({ statusCode: 400, statusMessage: 'El nombre es obligatorio' })
  }
  if (!rol || !ROLES_PERMITIDOS.includes(rol)) {
    throw createError({ statusCode: 400, statusMessage: 'Rol no permitido' })
  }

  const config = useRuntimeConfig(event)
  const hayClaveDeServicio = !!(config.supabase.serviceKey || config.supabase.secretKey)

  // La misma persona puede trabajar para varias empresas: si ya tiene cuenta,
  // no se crea otra, se le añade la pertenencia (docs/spec/10 §1).
  let usuarioId: string | undefined

  if (hayClaveDeServicio) {
    const admin = serverSupabaseServiceRole(event)

    const { data: existente, error: errBusqueda } = await admin
      .from('usuarios')
      .select('id')
      .eq('email', email)
      .maybeSingle()

    // Si la búsqueda falla no se puede concluir que la persona sea nueva: eso
    // pediría una contraseña para una cuenta que quizá ya existe. Mejor parar.
    if (errBusqueda) {
      throw createError({
        statusCode: 500,
        statusMessage: `No se pudo comprobar si el correo ya existe: ${errBusqueda.message}`,
      })
    }

    if (existente?.id) {
      usuarioId = existente.id
    }
    else {
      if (password.length < 8) {
        throw createError({
          statusCode: 400,
          statusMessage: 'La contraseña debe tener al menos 8 caracteres',
        })
      }

      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: nombre },
      })

      if (error) {
        throw createError({ statusCode: 400, statusMessage: error.message })
      }
      usuarioId = data.user?.id
    }
  }
  else {
    throw createError({
      statusCode: 501,
      statusMessage: 'Falta SUPABASE_SERVICE_KEY en el entorno: sin ella no se pueden crear cuentas.',
    })
  }

  if (!usuarioId) {
    throw createError({ statusCode: 500, statusMessage: 'No se pudo resolver el usuario' })
  }

  // El perfil se deriva del rol: `con_horario` es exactamente quien ficha.
  const { error: errPertenencia } = await db.from('pertenencias').insert({
    usuario_id: usuarioId,
    empresa_id: empresaId,
    rol,
    perfil: rol === 'trabajador' ? 'con_horario' : 'sin_horario',
    tarifa_hora: Number(body.tarifa_hora) || 0,
  })

  if (errPertenencia) {
    const yaEsta = errPertenencia.code === '23505'
    throw createError({
      statusCode: yaEsta ? 409 : 400,
      statusMessage: yaEsta
        ? 'Esa persona ya pertenece a esta empresa'
        : errPertenencia.message,
    })
  }

  return { usuario_id: usuarioId, email }
})
