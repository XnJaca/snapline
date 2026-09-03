import type { components } from '@snapline/contracts';

type Customer = components['schemas']['Customer'];

/**
 * Busca por lo que alguien tiene a mano cuando busca a un cliente: cómo le dice,
 * su correo, su teléfono o el nombre de su empresa.
 *
 * Función aparte y no un método del componente para poder probarla sin montar
 * media aplicación.
 */
export function filterCustomers(customers: readonly Customer[], query: string): Customer[] {
  const q = query.trim().toLowerCase();
  if (!q) return [...customers];

  return customers.filter((c) =>
    [c.displayName, c.email, c.phone, c.companyName].some((campo) =>
      campo?.toLowerCase().includes(q),
    ),
  );
}
