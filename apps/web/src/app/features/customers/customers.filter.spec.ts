import type { components } from '@snapline/contracts';
import { filterCustomers } from './customers.filter';

type Customer = components['schemas']['Customer'];

const CLIENTES = [
  { displayName: 'Martinez Residence', email: 'martinez@example.com', phone: '+15559876543', companyName: null },
  { displayName: 'Whitaker Home', email: null, phone: '+15554478890', companyName: null },
  { displayName: 'Delgado Property Group', email: 'ops@delgadopg.com', phone: null, companyName: 'Delgado PG' },
] as Customer[];

const nombres = (query: string) => filterCustomers(CLIENTES, query).map((c) => c.displayName);

describe('filterCustomers', () => {
  it('sin búsqueda devuelve todo', () => {
    expect(nombres('')).toHaveLength(3);
    expect(nombres('   ')).toHaveLength(3);
  });

  it('busca por nombre, sin importar mayúsculas', () => {
    expect(nombres('whitaker')).toEqual(['Whitaker Home']);
    expect(nombres('WHITAKER')).toEqual(['Whitaker Home']);
  });

  it('busca por correo', () => {
    expect(nombres('martinez@example')).toEqual(['Martinez Residence']);
  });

  // Se busca por el número como está guardado, que es E.164.
  it('busca por teléfono', () => {
    expect(nombres('5554478890')).toEqual(['Whitaker Home']);
  });

  it('busca por el nombre de la empresa', () => {
    expect(nombres('Delgado PG')).toEqual(['Delgado Property Group']);
  });

  it('un campo nulo no rompe la búsqueda', () => {
    expect(nombres('ops@')).toEqual(['Delgado Property Group']);
  });

  it('lo que no coincide con nadie devuelve vacío, no todo', () => {
    expect(nombres('nadie que exista')).toEqual([]);
  });
});
