import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { TranslocoModule } from '@jsverse/transloco';
import { buildPhoneGroup, PhoneField, phoneValue } from '../../../shared/phone-field/phone-field';
import { Chip, ChipTone } from '../../../shared/chip/chip';
import { PhonePipe } from '../../../core/format/phone.pipe';
import { REQUIRED_IN_WORDS } from '../../../shared/address-field/required-in-words';
import { toApiFailure } from '../../../core/api/api-failure';
import { CrewsApi, Member, MemberWithInvite } from '../crews.api';

export interface MemberDialogData {
  /** Ausente al agregar; presente al corregir. */
  member?: Member;
}

const ROLES = ['ADMIN', 'FOREMAN', 'WORKER', 'ACCOUNTANT'] as const;

@Component({
  selector: 'sl-member-dialog',
  imports: [
    ReactiveFormsModule, MatButtonModule, MatDialogModule, MatFormFieldModule,
    MatInputModule, MatProgressBarModule, MatSelectModule, TranslocoModule, PhoneField,
    Chip, PhonePipe,
  ],
  providers: [...REQUIRED_IN_WORDS],
  templateUrl: './member-dialog.html',
  styleUrls: ['./member-dialog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class MemberDialog {
  private readonly api = inject(CrewsApi);
  private readonly fb = inject(FormBuilder);
  private readonly ref = inject(
    MatDialogRef<MemberDialog, MemberWithInvite | Member | { regenerate: Member } | null>);

  protected readonly data = inject<MemberDialogData>(MAT_DIALOG_DATA, { optional: true }) ?? {};
  protected readonly busy = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly roles = ROLES;
  // OWNER no está en la lista: la empresa tiene exactamente uno y ya existe.
  protected readonly phone = buildPhoneGroup(this.fb, this.data.member?.phone);

  protected readonly form = this.fb.nonNullable.group({
    name: [this.data.member?.name ?? '', Validators.required],
    email: [this.data.member?.email ?? ''],
    role: [this.data.member?.role ?? 'WORKER'],
    // En dólares en la pantalla, en centavos en el contrato (regla 15).
    payRate: [this.data.member?.payRateCents ? this.data.member.payRateCents / 100 : null as number | null],
    employmentType: [this.data.member?.employmentType ?? null as string | null],
    locale: [this.data.member?.locale ?? 'es'],
  });

  protected get editing(): boolean {
    return !!this.data.member;
  }

  protected tone(status: string): ChipTone {
    return status === 'ACTIVE' ? 'success' : status === 'INVITED' ? 'info' : 'neutral';
  }

  protected async submit(): Promise<void> {
    this.form.markAllAsTouched();
    if (this.form.invalid || this.busy()) return;

    const raw = this.form.getRawValue();
    const payRateCents = raw.payRate === null ? null : Math.round(raw.payRate * 100);

    this.busy.set(true);
    this.error.set(null);
    try {
      const phone = phoneValue(this.phone);
      if (!phone && !raw.email) {
        this.error.set('crews.contactRequired');
        return;
      }

      if (this.data.member) {
        const updated = await this.api.updateMember(this.data.member.id, {
          role: raw.role,
          payRateCents,
          employmentType: raw.employmentType,
          name: raw.name,
          email: raw.email || undefined,
          phone: phone ?? undefined,
          locale: raw.locale,
        });
        this.ref.close(updated);
        return;
      }

      const created = await this.api.createMember({
        name: raw.name,
        email: raw.email || undefined,
        phone: phone ?? undefined,
        role: raw.role,
        payRateCents,
        employmentType: raw.employmentType,
        locale: raw.locale,
      });
      this.ref.close(created);
    } catch (cause) {
      // Lo escrito no se pierde: el diálogo queda abierto tal como estaba.
      const failure = toApiFailure(cause);
      this.error.set(
        failure.kind === 'network' ? 'form.error.connection'
          : failure.code === 'CONTACT_ALREADY_MEMBER' ? 'crews.alreadyMember'
            : failure.code === 'OWNER_ALREADY_EXISTS' ? 'crews.ownerExists'
              : 'form.error.unknown',
      );
    } finally {
      this.busy.set(false);
    }
  }

  /**
   * Emite un código nuevo sin salir del diálogo. El anterior deja de servir, así
   * que la pantalla lo confirma antes y muestra el nuevo después.
   */
  protected async regenerate(): Promise<void> {
    const member = this.data.member;
    if (!member || this.busy()) return;
    this.ref.close({ regenerate: member });
  }

  protected cancel(): void {
    this.ref.close(null);
  }
}
