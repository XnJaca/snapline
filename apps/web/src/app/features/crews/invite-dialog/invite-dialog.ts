import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { TranslocoModule } from '@jsverse/transloco';
import { DatePipe } from '../../../core/format/date.pipe';

export interface InviteData {
  name: string;
  code: string;
  expiresAt: string | null;
}

/**
 * El código se muestra una sola vez: en la base vive hasheado y no hay forma de
 * volver a leerlo. Por eso ocupa el diálogo entero y se separa en pares, que es
 * como se dicta en voz alta.
 */
@Component({
  selector: 'sl-invite-dialog',
  imports: [MatButtonModule, MatDialogModule, MatIconModule, TranslocoModule, DatePipe],
  templateUrl: './invite-dialog.html',
  styleUrls: ['./invite-dialog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class InviteDialog {
  protected readonly data = inject<InviteData>(MAT_DIALOG_DATA);
  private readonly ref = inject(MatDialogRef<InviteDialog>);

  protected readonly copied = signal(false);

  /** En pares, como se lee: "48, 29, 15". */
  protected readonly groups = [
    this.data.code.slice(0, 2),
    this.data.code.slice(2, 4),
    this.data.code.slice(4, 6),
  ];

  protected async copy(): Promise<void> {
    await navigator.clipboard.writeText(this.data.code);
    this.copied.set(true);
  }

  protected close(): void {
    this.ref.close();
  }
}
