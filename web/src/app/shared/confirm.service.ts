import { Injectable, signal } from '@angular/core';

export interface ConfirmRequest {
  title: string; message: string; confirmLabel?: string; danger?: boolean; resolve: (ok: boolean) => void;
}

@Injectable({ providedIn: 'root' })
export class ConfirmService {
  readonly current = signal<ConfirmRequest | null>(null);

  ask(title: string, message: string, opts: { confirmLabel?: string; danger?: boolean } = {}): Promise<boolean> {
    return new Promise(resolve => this.current.set({ title, message, ...opts, resolve }));
  }
  answer(ok: boolean): void {
    this.current()?.resolve(ok);
    this.current.set(null);
  }
}
