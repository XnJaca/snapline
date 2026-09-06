import type { Project } from './projects.api';
import { ALL_STATUSES, filterProjects } from './projects.filter';

const obra = (over: Partial<Project>): Project => ({
  id: 'p', name: 'Obra', status: 'LEAD', customerId: 'c1', siteId: 's1',
  description: null, serviceType: null, clientVisibilityMode: 'STAGES',
  startDate: null, targetEndDate: null, actualEndDate: null, publishedAt: null,
  deletedAt: null, companyId: 'co', createdAt: '', updatedAt: '',
  ...over,
} as Project);

const OBRAS = [
  obra({ id: 'p1', name: 'Techo Martinez', status: 'IN_PROGRESS', serviceType: 'roofing',
         customer: { displayName: 'Martinez Residence' } as Project['customer'] }),
  obra({ id: 'p2', name: 'Baño Nguyen', status: 'COMPLETED',
         customer: { displayName: 'Nguyen Residence' } as Project['customer'] }),
  obra({ id: 'p3', name: 'Cocina Whitaker', status: 'IN_PROGRESS',
         customer: { displayName: 'Whitaker Home' } as Project['customer'] }),
];

describe('filtro de la lista de obras', () => {
  it('sin búsqueda ni estado devuelve todo', () => {
    expect(filterProjects(OBRAS, '', ALL_STATUSES)).toHaveLength(3);
  });

  it('busca por nombre de obra', () => {
    expect(filterProjects(OBRAS, 'techo', ALL_STATUSES).map((p) => p.id)).toEqual(['p1']);
  });

  it('busca por nombre de cliente, que es como se pregunta por una obra', () => {
    expect(filterProjects(OBRAS, 'whitaker', ALL_STATUSES).map((p) => p.id)).toEqual(['p3']);
  });

  it('filtra por estado', () => {
    expect(filterProjects(OBRAS, '', 'IN_PROGRESS').map((p) => p.id)).toEqual(['p1', 'p3']);
  });

  it('los dos filtros se aplican juntos', () => {
    expect(filterProjects(OBRAS, 'nguyen', 'IN_PROGRESS')).toEqual([]);
    expect(filterProjects(OBRAS, 'nguyen', 'COMPLETED').map((p) => p.id)).toEqual(['p2']);
  });

  it('ignora espacios y mayúsculas', () => {
    expect(filterProjects(OBRAS, '  MARTINEZ  ', ALL_STATUSES).map((p) => p.id)).toEqual(['p1']);
  });

  it('una obra sin cliente cargado no rompe la búsqueda', () => {
    const suelta = [obra({ id: 'p4', name: 'Sin cliente' })];
    expect(filterProjects(suelta, 'algo', ALL_STATUSES)).toEqual([]);
    expect(filterProjects(suelta, 'sin', ALL_STATUSES)).toHaveLength(1);
  });
});
