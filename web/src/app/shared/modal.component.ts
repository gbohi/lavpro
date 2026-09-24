import { Component, EventEmitter, HostListener, Input, Output } from '@angular/core';

@Component({
  selector: 'app-modal',
  standalone: true,
  template: `
    @if (open) {
      <div class="backdrop" (click)="close.emit()"></div>
      <div class="modal" [style.max-width.px]="width" role="dialog" aria-modal="true">
        <header>
          <div>
            <h2>{{ title }}</h2>
            @if (subtitle) { <p class="muted small">{{ subtitle }}</p> }
          </div>
          <button class="btn ghost icon-only" (click)="close.emit()" aria-label="Fermer"><span class="icon">close</span></button>
        </header>
        <section><ng-content /></section>
        <footer><ng-content select="[modal-actions]" /></footer>
      </div>
    }
  `,
  styles: [`
    .backdrop { position: fixed; inset: 0; background: rgba(2, 6, 23, .55); backdrop-filter: blur(4px); z-index: 90; animation: fade .2s; }
    .modal { position: fixed; z-index: 91; left: 50%; top: 50%; transform: translate(-50%, -50%); width: calc(100% - 32px);
      max-height: calc(100vh - 48px); display: flex; flex-direction: column; background: var(--surface); border-radius: 20px;
      box-shadow: var(--shadow-lg); border: 1px solid var(--border); animation: pop .22s cubic-bezier(.2, .9, .3, 1.2); }
    header { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; padding: 22px 24px 10px; }
    section { padding: 10px 24px; overflow: auto; }
    footer { padding: 14px 24px 22px; display: flex; justify-content: flex-end; gap: 10px; flex-wrap: wrap; }
    footer:empty { display: none; }
    @keyframes fade { from { opacity: 0; } }
    @keyframes pop { from { opacity: 0; transform: translate(-50%, -46%) scale(.97); } }
  `],
})
export class ModalComponent {
  @Input() open = false;
  @Input() title = '';
  @Input() subtitle = '';
  @Input() width = 560;
  @Output() close = new EventEmitter<void>();

  @HostListener('document:keydown.escape')
  onEsc(): void { if (this.open) this.close.emit(); }
}
