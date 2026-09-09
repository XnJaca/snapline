import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { httpResource } from '@angular/common/http';
import { ActivatedRoute, Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatMenuModule } from '@angular/material/menu';
import { MatTabsModule } from '@angular/material/tabs';
import { TranslocoModule, TranslocoService } from '@jsverse/transloco';
import { API_BASE_URL } from '../../../core/api/api.config';
import { collection } from '../../../core/api/collection';
import { SessionService } from '../../../core/session/session.service';
import { Page } from '../../../shared/page/page';
import { DatePipe } from '../../../core/format/date.pipe';
import { CONFIRM_DIALOG_CONFIG, ConfirmDialog } from '../../../shared/confirm/confirm-dialog';
import { Crew, CrewAssignment, CrewMember, CrewsApi, Member } from '../crews.api';
import { CrewDialog } from '../crew-dialog/crew-dialog';
import { CrewMemberDialog } from '../crew-member-dialog/crew-member-dialog';
import { AssignDialog } from '../assign-dialog/assign-dialog';

@Component({
  selector: 'sl-crew-detail',
  imports: [
    MatButtonModule, MatFormFieldModule, MatIconModule, MatInputModule, MatMenuModule,
    MatTabsModule, TranslocoModule, Page, DatePipe,
  ],
  templateUrl: './crew-detail.html',
  styleUrls: ['./crew-detail.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CrewDetail {
  private readonly base = inject(API_BASE_URL);
  private readonly api = inject(CrewsApi);
  private readonly dialog = inject(MatDialog);
  private readonly router = inject(Router);
  private readonly session = inject(SessionService);
  private readonly transloco = inject(TranslocoService);

  protected readonly id = inject(ActivatedRoute).snapshot.paramMap.get('id') ?? '';

  protected readonly crew = httpResource<Crew>(() => `${this.base}/crews/${this.id}`);
  protected readonly members = httpResource<CrewMember[]>(
    () => `${this.base}/crews/${this.id}/members`, { defaultValue: [] });
  protected readonly assignments = httpResource<CrewAssignment[]>(
    () => `${this.base}/crews/${this.id}/assignments`, { defaultValue: [] });

  protected readonly canWrite = computed(() => this.session.can('crews.write'));
  protected readonly canManage = computed(() => this.session.can('members.manage'));
  protected readonly people = collection<Member>(() => this.canManage() ? '/memberships' : undefined);

  protected readonly loading = computed(
    () => this.crew.isLoading() || this.members.isLoading());

  protected readonly today = new Date().toISOString().slice(0, 10);
  protected readonly tab = signal(0);
  protected readonly query = signal('');

  /**
   * Por nombre, teléfono o correo. No hay cédula en el modelo: de un trabajador
   * se guarda con qué entra a la app, y eso es el teléfono o el correo.
   */
  protected readonly filteredMembers = computed(() => {
    const q = this.query().trim().toLowerCase();
    const rows = this.members.value();
    if (!q) return rows;

    const contacto = new Map(this.people.value().map((p) => [p.id, p]));
    return rows.filter((m) => {
      const persona = contacto.get(m.membershipId);
      return m.name.toLowerCase().includes(q)
        || (persona?.phone ?? '').toLowerCase().includes(q)
        || (persona?.email ?? '').toLowerCase().includes(q);
    });
  });

  /**
   * Dónde está trabajando hoy y dónde trabajó antes. La pregunta que se hace
   * quien abre esta ficha es la primera, así que van separadas y no en una tabla
   * con dos fechas que hay que comparar mentalmente.
   */
  protected readonly current = computed(() =>
    this.assignments.value().filter((a) => !a.toDate || a.toDate >= this.today));

  protected readonly past = computed(() =>
    this.assignments.value().filter((a) => !!a.toDate && a.toDate < this.today));

  /** Terminada no es lo mismo que borrada: se ve, con su período. */
  protected ended(member: CrewMember): boolean {
    return !!member.toDate && member.toDate < this.today;
  }

  protected async edit(): Promise<void> {
    const crew = this.crew.value();
    if (!crew) return;
    const ref = this.dialog.open(CrewDialog, {
      data: { crew, people: this.people.value() },
      width: '32rem',
      maxWidth: 'calc(100vw - 2rem)',
    });
    if (await ref.afterClosed().toPromise()) this.crew.reload();
  }

  protected async addMember(): Promise<void> {
    const ref = this.dialog.open(CrewMemberDialog, {
      data: {
        crewId: this.id,
        crewName: this.crew.value()?.name ?? '',
        people: this.people.value(),
        current: this.members.value(),
      },
      width: '32rem',
      maxWidth: 'calc(100vw - 2rem)',
    });
    if (await ref.afterClosed().toPromise()) {
      this.members.reload();
      this.crew.reload();
    }
  }

  protected async endMember(member: CrewMember): Promise<void> {
    const ok = await this.confirm(
      'crews.endMemberTitle', 'crews.endMemberBody', 'crews.endMemberConfirm',
      { name: member.name }, true,
    );
    if (!ok) return;

    await this.api.endCrewMember(this.id, member.id, this.today);
    this.members.reload();
    this.crew.reload();
  }

  protected async assign(): Promise<void> {
    const ref = this.dialog.open(AssignDialog, {
      data: { crewId: this.id, crewName: this.crew.value()?.name ?? '' },
      width: '32rem',
      maxWidth: 'calc(100vw - 2rem)',
    });
    if (await ref.afterClosed().toPromise()) this.assignments.reload();
  }

  /** La cuadrilla dejó de trabajar ahí. Es un hecho, y queda en el historial. */
  protected async removeFromJob(assignment: CrewAssignment): Promise<void> {
    const ok = await this.confirm(
      'crews.removeFromJobTitle', 'crews.removeFromJobBody', 'crews.removeFromJobConfirm',
      { crew: this.crew.value()?.name ?? '', project: assignment.projectName },
    );
    if (!ok) return;

    await this.api.endAssignment(assignment.projectId, assignment.id, this.today);
    this.assignments.reload();
  }

  /** Se cargó por error. Distinto de haber trabajado ahí y haber terminado. */
  protected async deleteAssignment(assignment: CrewAssignment): Promise<void> {
    const ok = await this.confirm(
      'crews.deleteAssignmentTitle', 'crews.deleteAssignmentBody',
      'crews.deleteAssignmentConfirm', {}, true,
    );
    if (!ok) return;

    await this.api.unassign(assignment.projectId, assignment.id);
    this.assignments.reload();
  }

  protected back(): void {
    void this.router.navigate(['/crews']);
  }

  private async confirm(
    title: string, body: string, confirmLabel: string,
    params: Record<string, unknown> = {}, danger = false,
  ): Promise<boolean> {
    const t = (k: string) => this.transloco.translate(k, params);
    return !!(await this.dialog.open(ConfirmDialog, {
      ...CONFIRM_DIALOG_CONFIG,
      data: { title: t(title), body: t(body), confirmLabel: t(confirmLabel), danger },
    }).afterClosed().toPromise());
  }
}
