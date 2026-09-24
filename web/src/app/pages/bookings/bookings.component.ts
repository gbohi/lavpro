import { DatePipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { CenterApi } from '../../core/center-api.service';
import { Booking, BookingStatus } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { isoDate } from '../../shared/period';

const STATUS: Record<BookingStatus, { label: string; cls: string }> = {
  pending: { label: 'En attente', cls: 'warning' },
  confirmed: { label: 'Confirmée', cls: '' },
  completed: { label: 'Terminée', cls: 'success' },
  cancelled: { label: 'Annulée', cls: 'danger' },
  no_show: { label: 'Absent', cls: 'neutral' },
};

@Component({
  selector: 'app-bookings',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Réservations</h1><p class="muted">Créneaux réservés par vos clients depuis l'application.</p></div>
        <div class="row">
          <button class="btn icon-only" (click)="shift(-1)"><span class="icon">chevron_left</span></button>
          <input class="input" type="date" [(ngModel)]="day" (change)="load()" style="width:170px">
          <button class="btn icon-only" (click)="shift(1)"><span class="icon">chevron_right</span></button>
          <button class="btn" (click)="today()">Aujourd'hui</button>
        </div>
      </div>
      <div class="grid grid-4 stats">
        <div class="card"><small>Total</small><strong>{{ bookings().length }}</strong></div>
        <div class="card"><small>À venir</small><strong>{{ count('confirmed') + count('pending') }}</strong></div>
        <div class="card"><small>Terminées</small><strong>{{ count('completed') }}</strong></div>
        <div class="card"><small>Annulées / absents</small><strong>{{ count('cancelled') + count('no_show') }}</strong></div>
      </div>
      <div class="card">
        @for (b of bookings(); track b.id) {
          <div class="booking" [class.faded]="b.status === 'cancelled' || b.status === 'no_show'">
            <div class="time"><strong>{{ b.start_at | date:'HH:mm' }}</strong><small>{{ b.end_at | date:'HH:mm' }}</small></div>
            <div class="line"></div>
            <div class="info">
              <strong>{{ b.client_name }}</strong>
              <div class="small muted">{{ b.service_name }} · {{ b.vehicle_type_name }} @if (b.client_phone) { · <a [href]="'tel:' + b.client_phone">{{ b.client_phone }}</a> }</div>
              @if (b.note) { <div class="small">“{{ b.note }}”</div> }
            </div>
            <span class="badge {{ status[b.status].cls }}">{{ status[b.status].label }}</span>
            @if (b.status === 'confirmed' || b.status === 'pending') {
              <div class="row actions">
                <button class="btn sm primary" (click)="startWash()"><span class="icon">local_car_wash</span>Accueillir</button>
                <button class="btn sm" (click)="set(b, 'no_show')">Absent</button>
                <button class="btn sm danger" (click)="set(b, 'cancelled')">Annuler</button>
              </div>
            }
          </div>
        } @empty {
          <div class="empty"><span class="icon">event_busy</span>Aucune réservation ce jour</div>
        }
      </div>
    </div>
  `,
  styles: [`
    .stats { margin-bottom: 20px; .card { padding: 16px 18px; } small { color: var(--text-2); font-weight: 600; display: block; } strong { font-size: 22px; font-weight: 800; } }
    .booking { display: flex; align-items: center; gap: 16px; padding: 14px 0; border-bottom: 1px dashed var(--border); flex-wrap: wrap;
      &:last-child { border-bottom: none; }
      &.faded { opacity: .55; }
      .time { width: 58px; text-align: center; strong { display: block; font-size: 17px; } small { color: var(--muted); } }
      .line { width: 4px; align-self: stretch; border-radius: 4px; background: var(--grad); }
      .info { flex: 1; min-width: 200px; }
    }
  `],
})
export class BookingsComponent implements OnInit {
  private api = inject(CenterApi);
  private toast = inject(ToastService);
  private router = inject(Router);
  status = STATUS;
  day = isoDate(new Date());
  bookings = signal<Booking[]>([]);
  counts = computed(() => this.bookings().reduce<Record<string, number>>((a, b) => ({ ...a, [b.status]: (a[b.status] ?? 0) + 1 }), {}));

  ngOnInit(): void { this.load(); }
  count(s: BookingStatus): number { return this.counts()[s] ?? 0; }

  load(): void { this.api.get<Booking[]>('/bookings', { day: this.day }).subscribe(b => this.bookings.set(b)); }
  shift(n: number): void {
    const d = new Date(this.day);
    d.setDate(d.getDate() + n);
    this.day = isoDate(d);
    this.load();
  }
  today(): void { this.day = isoDate(new Date()); this.load(); }

  set(b: Booking, status: BookingStatus): void {
    this.api.patch<Booking>(`/bookings/${b.id}`, { status }).subscribe(() => { this.toast.success('Réservation mise à jour'); this.load(); });
  }
  startWash(): void { this.router.navigate(['/validate']); }
}
