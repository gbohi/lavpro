import { Injectable, signal } from '@angular/core';

export interface Toast { id: number; kind: 'success' | 'error' | 'info'; message: string; }

@Injectable({ providedIn: 'root' })
export class ToastService {
  readonly toasts = signal<Toast[]>([]);
  private seq = 0;

  show(message: string, kind: Toast['kind'] = 'info', ms = 3800): void {
    const id = ++this.seq;
    this.toasts.update(t => [...t, { id, kind, message }]);
    setTimeout(() => this.dismiss(id), ms);
  }
  success(message: string): void { this.show(message, 'success'); }
  error(message: string): void { this.show(message, 'error', 5500); }
  dismiss(id: number): void { this.toasts.update(t => t.filter(x => x.id !== id)); }
}
