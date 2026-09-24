import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/auth.service';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { Wash } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { ConfirmService } from '../../shared/confirm.service';
import { daysAgo, download, isoDate } from '../../shared/period';

@Component({
  selector: 'app-washes',
  standalone: true,
  imports: [FormsModule, DatePipe, DecimalPipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Historique des lavages</h1><p class="muted">Tous les lavages validés, par qui et pour qui.</p></div>
        <button class="btn" (click)="export()"><span class="icon">download</span>Exporter (CSV)</button>
      </div>
      <div class="card filters">
        <div class="field"><label>Du</label><input class="input" type="date" [(ngModel)]="from" (change)="load()"></div>
        <div class="field"><label>Au</label><input class="input" type="date" [(ngModel)]="to" (change)="load()"></div>
        <div class="field"><label>Laveur</label>
          <select class="input" [(ngModel)]="washerId" (change)="load()">
            <option [ngValue]="null">Tous</option>
            @for (w of store.washers(); track w.id) { <option [ngValue]="w.id">{{ w.full_name }}</option> }
          </select>
        </div>
        <div class="field"><label>Service</label>
          <select class="input" [(ngModel)]="serviceId" (change)="load()">
            <option [ngValue]="null">Tous</option>
            @for (s of store.services(); track s.id) { <option [ngValue]="s.id">{{ s.name }}</option> }
          </select>
        </div>
      </div>
      <div class="grid grid-4 totals">
        <div class="card"><small>Lavages</small><strong>{{ washes().length }}</strong></div>
        <div class="card"><small>Montant</small><strong>{{ total().amount | number:'1.0-0' }} {{ store.currency }}</strong></div>
        <div class="card"><small>Points distribués</small><strong>{{ total().points | number }}</strong></div>
        <div class="card"><small>Offerts / payés en points</small><strong>{{ total().free }}</strong></div>
      </div>
      <div class="card flush">
        <div class="table-wrap">
          <table class="table">
            <thead><tr><th>Date</th><th>Client</th><th>Service</th><th>Véhicule</th><th>Laveur</th><th>Validé par</th><th>Règlement</th><th class="num">Montant</th><th class="num">Points</th><th></th></tr></thead>
            <tbody>
              @for (w of washes(); track w.id) {
                <tr>
                  <td><strong>{{ w.created_at | date:'dd MMM' }}</strong><div class="small muted">{{ w.created_at | date:'HH:mm' }}</div></td>
                  <td>{{ w.client_name ?? 'Client de passage' }}</td>
                  <td>{{ w.service_name }}</td>
                  <td>{{ w.vehicle_type_name }} @if (w.plate) { <div class="small muted">{{ w.plate }}</div> }</td>
                  <td>@if (w.washer_name) { <span class="badge neutral">{{ w.washer_name }}</span> } @else { <span class="muted">—</span> }</td>
                  <td class="small">{{ w.validated_by_name }}</td>
                  <td>@switch (w.payment_method) {
                    @case ('reward') { <span class="badge success"><span class="icon">redeem</span>Récompense</span> }
                    @case ('points') { <span class="badge" style="background:rgba(139,92,246,.12);color:#7c3aed"><span class="icon">stars</span>{{ w.points_spent }} pts</span> }
                    @default { <span class="badge neutral">Payé</span> }
                  }</td>
                  <td class="num">{{ w.price | number:'1.0-0' }} @if (w.discount && w.payment_method === 'standard') { <div class="small" style="color:var(--success)">-{{ w.discount | number:'1.0-0' }}</div> }</td>
                  <td class="num"><strong>{{ w.payment_method === 'points' ? '−' + w.points_spent : '+' + w.points_earned }}</strong></td>
                  <td class="num">@if (auth.isOwner()) { <button class="btn ghost icon-only sm" title="Annuler" (click)="cancel(w)"><span class="icon">delete</span></button> }</td>
                </tr>
              } @empty {
                <tr><td colspan="10"><div class="empty"><span class="icon">local_car_wash</span>Aucun lavage sur cette période</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .filters { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; margin-bottom: 20px; }
    @media (max-width: 720px) { .filters { grid-template-columns: 1fr 1fr; } }
    .totals { margin-bottom: 20px; .card { padding: 16px 18px; } small { color: var(--text-2); font-weight: 600; display: block; } strong { font-size: 22px; font-weight: 800; } }
  `],
})
export class WashesComponent implements OnInit {
  private api = inject(CenterApi);
  private toast = inject(ToastService);
  private confirm = inject(ConfirmService);
  store = inject(CenterStore);
  auth = inject(AuthService);
  washes = signal<Wash[]>([]);
  from = daysAgo(6);
  to = isoDate(new Date());
  washerId: number | null = null;
  serviceId: number | null = null;

  total = computed(() => this.washes().reduce((a, w) => ({
    amount: a.amount + w.price, points: a.points + w.points_earned, free: a.free + (w.payment_method === 'standard' ? 0 : 1),
  }), { amount: 0, points: 0, free: 0 }));

  ngOnInit(): void { this.load(); }

  load(): void {
    this.api.get<Wash[]>('/washes', { date_from: this.from, date_to: this.to, washer_id: this.washerId, service_type_id: this.serviceId, limit: 1000 })
      .subscribe(w => this.washes.set(w));
  }

  export(): void {
    this.api.blob('/washes/export', { date_from: this.from, date_to: this.to, washer_id: this.washerId })
      .subscribe(b => download(b, `lavages_${this.from}_${this.to}.csv`));
  }

  async cancel(w: Wash): Promise<void> {
    if (!await this.confirm.ask('Annuler ce lavage ?', 'Les points attribués au client seront retirés.', { danger: true, confirmLabel: 'Annuler le lavage' })) return;
    this.api.delete(`/washes/${w.id}`).subscribe(() => { this.toast.success('Lavage annulé'); this.load(); });
  }
}
