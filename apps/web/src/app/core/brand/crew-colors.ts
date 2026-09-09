/**
 * Los colores que se ofrecen para distinguir una cuadrilla.
 *
 * **No son tokens de tema y no deben serlo**: el color de una cuadrilla es un
 * dato que elige el usuario y que después se pinta tal cual, igual que el nombre.
 * Lo que sí es decisión del sistema es *qué* paleta se ofrece —seis opciones
 * legibles sobre las dos superficies— y por eso vive acá y no adentro de un
 * componente, donde la regla 22 no la distinguiría de un hex hardcodeado.
 */
export const CREW_COLORS = [
  '#2563eb',
  '#16a34a',
  '#ea580c',
  '#9333ea',
  '#0891b2',
  '#dc2626',
] as const;
