import { Routes } from '@angular/router';
import { anonymousGuard, sessionGuard } from './core/session/session.guard';

export const routes: Routes = [
  {
    path: 'login',
    canActivate: [anonymousGuard],
    loadComponent: () => import('./features/login/login').then((m) => m.Login),
  },
  // Andamiaje de SPEC-0007: fuera del shell y sin sesión, porque es donde se
  // comprueba la paridad de tokens mirando.
  {
    path: 'dev/tokens',
    loadComponent: () => import('./features/dev-tokens/dev-tokens').then((m) => m.DevTokens),
  },
  {
    path: '',
    canActivate: [sessionGuard],
    loadComponent: () => import('./features/shell/shell').then((m) => m.Shell),
    children: [
      { path: 'projects', loadComponent: () => import('./features/projects/projects').then((m) => m.Projects) },
      { path: 'customers', loadComponent: () => import('./features/customers/customers').then((m) => m.Customers) },
      // `new` antes que `:id`, o se toma por un id.
      { path: 'customers/new', loadComponent: () => import('./features/customers/customer-form/customer-form').then((m) => m.CustomerForm) },
      { path: 'customers/:id', loadComponent: () => import('./features/customers/customer-detail/customer-detail').then((m) => m.CustomerDetail) },
      { path: 'customers/:id/edit', loadComponent: () => import('./features/customers/customer-form/customer-form').then((m) => m.CustomerForm) },
      { path: 'crews', loadComponent: () => import('./features/crews/crews').then((m) => m.Crews) },
      { path: 'hours', loadComponent: () => import('./features/hours/hours').then((m) => m.Hours) },
      { path: 'catalog', loadComponent: () => import('./features/catalog/catalog').then((m) => m.Catalog) },
      { path: 'billing', loadComponent: () => import('./features/billing/billing').then((m) => m.Billing) },
      { path: 'reports', loadComponent: () => import('./features/reports/reports').then((m) => m.Reports) },
      { path: 'publish', loadComponent: () => import('./features/publish/publish').then((m) => m.Publish) },
      { path: '', pathMatch: 'full', redirectTo: 'projects' },
    ],
  },
  { path: '**', redirectTo: '' },
];
