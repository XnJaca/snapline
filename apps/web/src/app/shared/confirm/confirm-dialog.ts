import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogConfig, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { TranslocoModule } from '@jsverse/transloco';

export interface ConfirmData {
  title: string;
  body: string;
  confirmLabel: string;
  /** Pinta la acción como destructiva. Borrar no se ve igual que guardar. */
  danger?: boolean;
}

/**
 * Con qué se abre. El foco va al diálogo y no al primer botón: un botón
 * enfocado por programa se pinta como si estuviera presionado, y en una
 * confirmación destructiva nada tiene que verse preseleccionado.
 */
export const CONFIRM_DIALOG_CONFIG: MatDialogConfig = {
  width: '32rem',
  maxWidth: 'calc(100vw - 2rem)',
  autoFocus: 'dialog',
};

@Component({
  selector: 'sl-confirm-dialog',
  imports: [MatButtonModule, MatDialogModule, MatIconModule, TranslocoModule],
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
