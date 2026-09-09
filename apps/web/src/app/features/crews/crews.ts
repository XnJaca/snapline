import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatMenuModule } from '@angular/material/menu';
import { MatTabsModule } from '@angular/material/tabs';
import { TranslocoModule, TranslocoService } from '@jsverse/transloco';
import { collection } from '../../core/api/collection';
import { SessionService } from '../../core/session/session.service';
import { Page } from '../../shared/page/page';
import { Chip, ChipTone } from '../../shared/chip/chip';
import { MoneyPipe } from '../../core/format/money.pipe';
import { PhonePipe } from '../../core/format/phone.pipe';
import { CONFIRM_DIALOG_CONFIG, ConfirmDialog } from '../../shared/confirm/confirm-dialog';
import { Crew, CrewsApi, Member } from './crews.api';
import { MemberDialog } from './member-dialog/member-dialog';
import { CrewDialog } from './crew-dialog/crew-dialog';
import { InviteDialog } from './invite-dialog/invite-dialog';

const TONE_BY_STATUS: Record<string, ChipTone> = {
  ACTIVE: 'success',
  INVITED: 'info',
  INACTIVE: 'neutral',
};

@Component({
  selector: 'sl-crews',
  imports: [
    MatButtonModule, MatFormFieldModule, MatIconModule, MatInputModule, MatMenuModule,
    MatTabsModule, TranslocoModule, RouterLink, Page, Chip, MoneyPipe, PhonePipe,
  ],
  templateUrl: './crews.html',
  styleUrls: ['./crews.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Crews {
  private readonly api = inject(CrewsApi);
  private readonly dialog = inject(MatDialog);
  private readonly router = inject(Router);
  private readonly session = inject(SessionService);
  private readonly transloco = inject(TranslocoService);

  protected readonly crews = collection<Crew>(() => '/crews');
  protected readonly tab = signal(0);
  protected readonly query = signal('');

  /**
   * La pestaña de gente cuelga de `members.manage`, no de `crews.read`: es por
   * donde sale la tarifa. Un FOREMAN entra al eje y ve sus cuadrillas, nada más.
   */
  protected readonly canManage = computed(() => this.session.can('members.manage'));
  protected readonly canWrite = computed(() => this.session.can('crews.write'));

  // Se pide solo si se puede: sin el permiso, el GET responde 403.
  protected readonly people = collection<Member>(() =>
    this.canManage() ? '/memberships' : undefined);

  protected readonly filtered = computed(() => {
    const q = this.query().trim().toLowerCase();
    const rows = this.people.value();
    if (!q) return rows;
    return rows.filter((m) =>
      m.name.toLowerCase().includes(q)
      || (m.phone ?? '').toLowerCase().includes(q)
      || (m.email ?? '').toLowerCase().includes(q));
  });

  protected readonly emptyByFilter = computed(
    () => this.people.value().length > 0 && this.filtered().length === 0);

  protected readonly loading = computed(
    () => this.crews.isLoading() || this.people.isLoading());

  protected tone(status: string): ChipTone {
    return TONE_BY_STATUS[status] ?? 'neutral';
  }

  protected openCrew(id: string): void {
    void this.router.navigate(['/crews', id]);
  }

  // ---------------------------------------------------------------- cuadrillas

  protected async newCrew(crew?: Crew): Promise<void> {
    const ref = this.dialog.open(CrewDialog, {
      data: { crew, people: this.people.value() },
      width: '32rem',
      maxWidth: 'calc(100vw - 2rem)',
    });
    if (await ref.afterClosed().toPromise()) this.crews.reload();
  }

  // --------------------------------------------------------------------- gente

  protected async newPerson(): Promise<void> {
    const ref = this.dialog.open(MemberDialog, {
      width: '40rem',
      maxWidth: 'calc(100vw - 2rem)',
    });
    const created = await ref.afterClosed().toPromise();
    this.people.reload();
    // El código sale una sola vez: si la pantalla no lo muestra ahora, hay que
    // regenerarlo, y regenerar expulsa a quien ya esté adentro.
    if (created?.inviteCode) this.showCode(created.name, created.inviteCode, created.inviteExpiresAt);
  }

  protected async editPerson(member: Member): Promise<void> {
    const ref = this.dialog.open(MemberDialog, {
      data: { member },
      width: '40rem',
      maxWidth: 'calc(100vw - 2rem)',
    });
    const result = await ref.afterClosed().toPromise();
    if (!result) return;

    // Pidió un código nuevo desde el formulario: se confirma y se emite acá,
    // para que la advertencia y el código sean los mismos que en la lista.
    if ('regenerate' in result) {
      await this.regenerate(result.regenerate);
      return;
    }
    this.people.reload();
  }

  protected async regenerate(member: Member): Promise<void> {
    const t = (k: string, p?: Record<string, unknown>) => this.transloco.translate(k, p);
    const ok = await this.dialog.open(ConfirmDialog, {
      ...CONFIRM_DIALOG_CONFIG,
      data: {
        title: t('crews.regenerateTitle', { name: member.name }),
        body: t('crews.regenerateBody', { name: member.name }),
        confirmLabel: t('crews.regenerateConfirm'),
      },
    }).afterClosed().toPromise();
    if (!ok) return;

    const fresh = await this.api.regenerateInvite(member.id);
    this.people.reload();
    this.showCode(fresh.name, fresh.inviteCode, fresh.inviteExpiresAt);
  }

  protected async deactivate(member: Member): Promise<void> {
    const t = (k: string, p?: Record<string, unknown>) => this.transloco.translate(k, p);
    const ok = await this.dialog.open(ConfirmDialog, {
      ...CONFIRM_DIALOG_CONFIG,
      data: {
        title: t('crews.deactivateTitle', { name: member.name }),
        body: t('crews.deactivateBody', { name: member.name }),
        confirmLabel: t('crews.deactivateConfirm'),
        danger: true,
      },
    }).afterClosed().toPromise();
    if (!ok) return;

    await this.api.deactivate(member.id);
    this.people.reload();
  }

  private showCode(name: string, code: string, expiresAt?: string | null): void {
    this.dialog.open(InviteDialog, {
      ...CONFIRM_DIALOG_CONFIG,
      data: { name, code, expiresAt: expiresAt ?? null },
    });
  }
}
