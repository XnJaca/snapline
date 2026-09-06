import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { httpResource } from '@angular/common/http';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { TranslocoModule } from '@jsverse/transloco';
import { API_BASE_URL } from '../../../core/api/api.config';
import { SessionService } from '../../../core/session/session.service';
import { Page } from '../../../shared/page/page';
import { Chip, ChipTone } from '../../../shared/chip/chip';
import { DatePipe } from '../../../core/format/date.pipe';
import { CountryPipe } from '../../../core/format/country.pipe';
import { projectStatusTone } from '../project-status';
import type { Project } from '../projects.api';

type Address = { line1?: string; line2?: string; city?: string; state?: string; postalCode?: string; country?: string };

@Component({
  selector: 'sl-project-detail',
  imports: [
    RouterLink, MatButtonModule, MatIconModule, TranslocoModule,
    Page, Chip, DatePipe, CountryPipe,
  ],
  templateUrl: './project-detail.html',
  styleUrls: ['./project-detail.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ProjectDetail {
  private readonly base = inject(API_BASE_URL);
  private readonly session = inject(SessionService);

  protected readonly id = inject(ActivatedRoute).snapshot.paramMap.get('id') ?? '';

  protected readonly project = httpResource<Project>(() => `${this.base}/projects/${this.id}`);

  /**
   * El enlace al cliente cuelga de `customers.read`, que no es el permiso que
   * abre esta pantalla: FOREMAN y WORKER tienen `projects.read` y no el otro.
   * Para ellos el nombre se muestra como texto, en vez de mandarlos a una ruta
   * que el nav ya les esconde y que el API responde con 403.
   */
  protected readonly canOpenCustomer = computed(() => this.session.can('customers.read'));

  protected get tone(): ChipTone {
    return projectStatusTone(this.project.value()?.status ?? '');
  }

  protected address(value: unknown): Address | null {
    return (value as Address | null) ?? null;
  }
}
