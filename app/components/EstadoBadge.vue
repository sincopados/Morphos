<script setup lang="ts">
import type { EmpresaEstado, ObraEstado } from '#shared/types/database'

const props = defineProps<{
  estado: EmpresaEstado | ObraEstado
  tipo?: 'empresa' | 'obra'
}>()

const colores: Record<string, 'success' | 'error' | 'warning' | 'neutral' | 'info'> = {
  activa: 'success',
  bloqueada: 'error',
  dada_de_baja: 'neutral',
  borrador: 'neutral',
  atrasada: 'warning',
  completada: 'info',
  cerrada: 'neutral',
  archivada: 'neutral',
}

const clave = computed(() =>
  props.tipo === 'obra' ? `obra.estado.${props.estado}` : `empresa.estado.${props.estado}`,
)
</script>

<template>
  <UBadge
    :color="colores[estado] ?? 'neutral'"
    variant="subtle"
    size="sm"
  >
    {{ $t(clave) }}
  </UBadge>
</template>
