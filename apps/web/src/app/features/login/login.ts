import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { TranslocoModule } from '@jsverse/transloco';
import { SessionService } from '../../core/session/session.service';
import { Logo } from '../../core/brand/logo';
import { toApiFailure } from '../../core/api/api-failure';

type LoginError = 'credentials' | 'connection' | 'server' | 'unknown';

@Component({
  selector: 'sl-login',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressBarModule,
    TranslocoModule,
    Logo,
  ],
  templateUrl: './login.html',
  styleUrls: ['./login.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Login {
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);

  protected readonly busy = signal(false);
  protected readonly error = signal<LoginError | null>(null);

  // Un solo campo de identificación: `email` y `phone` son opcionales en el
  // dominio y basta uno. El servidor decide cuál de los dos escribió.
  protected readonly form = inject(FormBuilder).nonNullable.group({
    identifier: ['', Validators.required],
    password: ['', [Validators.required, Validators.minLength(8)]],
  });

  protected async submit(): Promise<void> {
    if (this.form.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set(null);
    const { identifier, password } = this.form.getRawValue();

    try {
      await this.session.login(identifier.trim(), password);
      await this.router.navigateByUrl('/');
    } catch (cause) {
      this.error.set(this.classify(cause));
    } finally {
      this.busy.set(false);
    }
  }

  /** Sin red no hay respuesta, así que tampoco hay `code` que traducir. */
  private classify(cause: unknown): LoginError {
    const failure = toApiFailure(cause);
    if (failure.kind === 'network') return 'connection';
    if (failure.code === 'INVALID_CREDENTIALS') return 'credentials';
    return failure.status >= 500 ? 'server' : 'unknown';
  }
}
