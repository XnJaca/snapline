import { inject, Injectable } from '@angular/core';
import { MatStepperIntl } from '@angular/material/stepper';
import { TranslocoService } from '@jsverse/transloco';

/**
 * Material trae su etiqueta de paso opcional en inglés y fija. Sin esto, un
 * panel en español muestra "Optional" (regla 24).
 */
@Injectable()
export class StepperIntl extends MatStepperIntl {
  private readonly transloco = inject(TranslocoService);

  constructor() {
    super();
    this.transloco.langChanges$.subscribe(() => {
      this.optionalLabel = this.transloco.translate('action.optional');
      this.changes.next();
    });
  }
}
