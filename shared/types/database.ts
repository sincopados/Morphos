// Tipos del esquema de supabase/migrations/.
// Escritos a mano: regenerar con `supabase gen types typescript` cuando el
// esquema cambie de forma significativa.

export type UserRole
  = | 'owner'
    | 'administrador'
    | 'trabajador'
    | 'vendedor'
    | 'afiliado'

export type GlobalRole = 'morphos_core'
export type ProfileType = 'con_horario' | 'sin_horario'
export type EmpresaEstado = 'activa' | 'bloqueada' | 'dada_de_baja'
export type RegistroEstado = 'pendiente' | 'confirmado'
export type TareaEstado = 'abierta' | 'en_curso' | 'completada'
export type BloqueTipo = 'dia_completo' | 'medio_dia'
export type IncidenciaEstado = 'abierta' | 'en_curso' | 'cerrada'
export type IncidenciaPrioridad = 'baja' | 'media' | 'alta'
export type IncidenciaTipo = 'pago' | 'saldo' | 'datos' | 'tecnico' | 'otro'
export type EgresoCategoria
  = | 'infraestructura'
    | 'nomina'
    | 'proveedores'
    | 'comisiones'
    | 'otros'

export type ObraEstado
  = | 'borrador'
    | 'activa'
    | 'atrasada'
    | 'completada'
    | 'cerrada'
    | 'archivada'

export type Usuario = {
  id: string
  email: string
  nombre: string
  avatar_url: string | null
  rol_global: GlobalRole | null
  es_raiz: boolean
  activo: boolean
  eliminado_en: string | null
  created_at: string
}

export type Empresa = {
  id: string
  nombre: string
  slug: string
  jurisdiccion: string
  zona_horaria: string
  estado: EmpresaEstado
  supervision_contratada: boolean
  supervision_desde: string | null
  compliance_cargado: boolean
  dada_de_baja_en: string | null
  created_at: string
}

export type Pertenencia = {
  id: string
  usuario_id: string
  empresa_id: string
  rol: UserRole
  perfil: ProfileType
  tarifa_hora: number
  activa: boolean
  created_at: string
}

export type Membresia = {
  id: string
  empresa_id: string
  titular_id: string
  importe: number
  moneda: string
  vence_el: string
  created_at: string
}

export type PagoMembresia = {
  id: string
  membresia_id: string
  fecha: string
  importe: number
  ciclo: string
  metodo: string | null
  fallido: boolean
  registrado_por: string | null
  created_at: string
}

export type EgresoMorphos = {
  id: string
  fecha: string
  concepto: string
  categoria: EgresoCategoria
  importe: number
  comprobante_url: string | null
  registrado_por: string
  created_at: string
}

export type Incidencia = {
  id: string
  empresa_id: string
  abierta_por: string
  asunto: string
  tipo: IncidenciaTipo
  prioridad: IncidenciaPrioridad
  estado: IncidenciaEstado
  responsable: string | null
  created_at: string
  cerrada_en: string | null
}

export type IncidenciaMensaje = {
  id: string
  incidencia_id: string
  autor_id: string
  cuerpo: string
  created_at: string
}

export type Cliente = {
  id: string
  empresa_id: string
  nombre: string
  email: string | null
  telefono: string | null
  direccion: string | null
  created_at: string
}

export type Obra = {
  id: string
  empresa_id: string
  numero: number
  titulo: string
  cliente_id: string | null
  direccion_obra: string | null
  tipo: 'puntual' | 'recurrente'
  estado: ObraEstado
  fecha_inicio: string | null
  fecha_fin: string | null
  vendedor_id: string | null
  deposito_requerido: number
  notas_internas: string | null
  creado_por: string | null
  created_at: string
  updated_at: string
}

export type ObraLinea = {
  id: string
  obra_id: string
  orden: number
  nombre: string
  descripcion: string | null
  cantidad: number
  coste_unitario: number
  precio_unitario: number
  es_incluido: boolean
}

export type ObraGasto = {
  id: string
  obra_id: string
  fecha: string
  concepto: string
  categoria: string | null
  importe: number
  proveedor: string | null
  comprobante_url: string | null
  registrado_por: string | null
  estado: RegistroEstado
  created_at: string
}

export type Bloque = {
  id: string
  pertenencia_id: string
  obra_id: string
  fecha: string
  tipo: BloqueTipo
  entrada_at: string | null
  salida_at: string | null
  ajuste_horas: number
  tarifa_hora: number
  notas: string | null
  estado: RegistroEstado
  created_at: string
}

export type ObraTarea = {
  id: string
  obra_id: string
  titulo: string
  asignado_a: string | null
  fecha_limite: string | null
  estado: TareaEstado
  prioridad: IncidenciaPrioridad
  created_at: string
}

export type Cobro = {
  id: string
  obra_id: string
  factura_id: string | null
  fecha: string
  importe: number
  metodo: string | null
  tipo: 'deposito' | 'pago' | 'pago_final'
  estado: RegistroEstado
  created_at: string
}

type Table<Row, Insert = Partial<Row>> = {
  Row: Row
  Insert: Insert
  Update: Partial<Row>
  Relationships: []
}

export interface Database {
  public: {
    Tables: {
      usuarios: Table<Usuario>
      empresas: Table<Empresa>
      pertenencias: Table<Pertenencia>
      membresias: Table<Membresia>
      pagos_membresia: Table<PagoMembresia>
      egresos_morphos: Table<EgresoMorphos>
      incidencias: Table<Incidencia>
      incidencia_mensajes: Table<IncidenciaMensaje>
      clientes: Table<Cliente>
      obras: Table<Obra>
      obra_lineas: Table<ObraLinea>
      obra_gastos: Table<ObraGasto>
      bloques: Table<Bloque>
      obra_tareas: Table<ObraTarea>
      cobros: Table<Cobro>
    }
    Views: Record<string, never>
    Functions: Record<string, never>
    Enums: {
      user_role: UserRole
      empresa_estado: EmpresaEstado
    }
    CompositeTypes: Record<string, never>
  }
}
