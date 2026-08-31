import { Routes } from '@angular/router';

export const routes: Routes = [
  // Andamiaje de SPEC-0007: no cuelga de ninguna navegación porque el shell llega
  // con SPEC-0008. Es donde se comprueba la paridad de tokens mirando.
  {
    path: 'dev/tokens',
    loadComponent: () => import('./features/dev-tokens/dev-tokens').then((m) => m.DevTokens),
  },
  { path: '', pathMatch: 'full', redirectTo: 'dev/tokens' },
];
