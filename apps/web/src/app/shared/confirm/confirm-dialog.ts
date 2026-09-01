import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { TranslocoModule } from '@jsverse/transloco';

export interface ConfirmData {
  title: string;
  body: string;
  confirmLabel: string;
  /** Pinta la acción como destructiva. Borrar no se ve igual que guardar. */
  danger?: boolean;
}

@Component({
  selector: 'sl-confirm-dialog',
  imports: [MatButtonModule, MatDialogModule, TranslocoModule],
  templateUrl: './confirm-dialog.html',
  styleUrls: ['./confirm-dialog.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ConfirmDialog {
  protected readonly data = inject<ConfirmData>(MAT_DIALOG_DATA);
  private readonly ref = inject(MatDialogRef<ConfirmDialog, boolean>);

  protected close(ok: boolean): void {
    this.ref.close(ok);
  }
}
