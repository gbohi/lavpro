import { Component, inject } from '@angular/core';
import { ToastService } from '../core/toast.service';
import { ConfirmService } from './confirm.service';
import { ModalComponent } from './modal.component';

@Component({
  selector: 'app-overlays',
  standalone: true,
  imports: [ModalComponent],
  template: `
    <div class="toasts">
      @for (t of toast.toasts(); track t.id) {
        <div class="toast" [class]="t.kind" (click)="toast.dismiss(t.id)">
          <span class="icon filled">{{ t.kind === 'success' ? 'check_circle' : t.kind === 'error' ? 'error' : 'info' }}</span>
          <span>{{ t.message }}</span>
        </div>
      }
    </div>
    @if (confirm.current(); as c) {
      <app-modal [open]="true" [title]="c.title" [width]="440" (close)="confirm.answer(false)">
        <p class="muted">{{ c.message }}</p>
        <div modal-actions>
          <button class="btn" (click)="confirm.answer(false)">Annuler</button>
          <button class="btn" [class.primary]="!c.danger" [class.danger]="c.danger" (click)="confirm.answer(true)">
            {{ c.confirmLabel || 'Confirmer' }}
          </button>
        </div>
      </app-modal>
    }
  `,
  styles: [`
    .toasts { position: fixed; right: 20px; bottom: 20px; z-index: 200; display: flex; flex-direction: column; gap: 10px; max-width: min(420px, calc(100vw - 40px)); }
    .toast { display: flex; gap: 10px; align-items: center; padding: 14px 16px; border-radius: 14px; background: var(--surface);
      border: 1px solid var(--border); box-shadow: var(--shadow-lg); font-weight: 600; cursor: pointer; animation: slide .25s ease; }
    .toast.success .icon { color: var(--success); }
    .toast.error .icon { color: var(--danger); }
    .toast.info .icon { color: var(--primary); }
    @keyframes slide { from { opacity: 0; transform: translateX(20px); } }
  `],
})
export class OverlaysComponent {
  toast = inject(ToastService);
  confirm = inject(ConfirmService);
}
