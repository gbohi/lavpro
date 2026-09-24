import { DecimalPipe, KeyValuePipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ChartConfiguration } from 'chart.js';
import { CenterApi } from '../../core/center-api.service';
import { Dashboard } from '../../core/models';
import { ChartComponent, PALETTE } from '../../shared/chart.component';
import { PERIODS, daysAgo, download, isoDate } from '../../shared/period';

@Component({
  selector: 'app-reports',
  standalone: true,
  imports: [FormsModule, DecimalPipe, KeyValuePipe, ChartComponent],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Rapports</h1><p class="muted">Point de lavage par laveur, services, véhicules : de quoi ajuster vos prix et cibler vos promotions.</p></div>
        <div class="row">
          <div class="chips">@for (p of periods.slice(1); track p.days) { <button class="chip" [class.active]="period() === p.days" (click)="setPeriod(p.days)">{{ p.label }}</button> }</div>
          <input class="input" type="date" [(ngModel)]="from" (change)="period.set(-1); load()" style="width:150px">
          <input class="input" type="date" [(ngModel)]="to" (change)="period.set(-1); load()" style="width:150px">
          <button class="btn" (click)="export()"><span class="icon">download</span>CSV</button>
        </div>
      </div>

      @if (data(); as d) {
        <div class="card flush">
          <div class="card-head pad"><h2>Point de lavage par laveur</h2><span class="badge neutral">{{ d.kpis.washes }} lavages · {{ d.kpis.revenue | number:'1.0-0' }} {{ d.currency }}</span></div>
          <div class="table-wrap">
            <table class="table">
              <thead><tr><th>Laveur</th><th class="num">Lavages</th><th class="num">Part</th><th class="num">Chiffre d'affaires</th><th class="num">Commission</th><th>Détail par service</th></tr></thead>
              <tbody>
                @for (w of washers(); track w.id) {
                  <tr>
                    <td><strong>{{ w.name }}</strong></td>
                    <td class="num"><strong>{{ w.count }}</strong></td>
                    <td class="num">{{ (d.kpis.washes ? w.count / d.kpis.washes * 100 : 0) | number:'1.0-1' }} %</td>
                    <td class="num">{{ w.revenue | number:'1.0-0' }} {{ d.currency }}</td>
                    <td class="num">{{ w.commission | number:'1.0-0' }} {{ d.currency }}</td>
                    <td><div class="chips">@for (s of w.services | keyvalue; track s.key) { <span class="badge neutral">{{ s.key }} : {{ s.value }}</span> }</div></td>
                  </tr>
                } @empty { <tr><td colspan="6"><div class="empty">Aucun lavage sur la période</div></td></tr> }
              </tbody>
            </table>
          </div>
        </div>

        <div class="grid grid-2 mt">
          <div class="card">
            <div class="card-head"><h2>Chiffre d'affaires par service</h2></div>
            <app-chart [config]="servicesChart()" [height]="280" />
          </div>
          <div class="card">
            <div class="card-head"><h2>Répartition par type de véhicule</h2></div>
            <app-chart [config]="vehiclesChart()" [height]="280" />
          </div>
        </div>

        <div class="card flush mt">
          <div class="card-head pad"><h2>Services</h2></div>
          <div class="table-wrap">
            <table class="table">
              <thead><tr><th>Service</th><th class="num">Lavages</th><th class="num">Part</th><th class="num">CA</th><th class="num">Prix moyen</th></tr></thead>
              <tbody>
                @for (s of d.services; track s.id) {
                  <tr><td><strong>{{ s.name }}</strong></td><td class="num">{{ s.count }}</td><td class="num">{{ s.share }} %</td>
                    <td class="num">{{ s.revenue | number:'1.0-0' }}</td><td class="num">{{ (s.count ? s.revenue / s.count : 0) | number:'1.0-0' }}</td></tr>
                }
              </tbody>
            </table>
          </div>
        </div>

        <div class="grid grid-4 mt">
          <div class="card stat"><small>Clients récurrents</small><strong>{{ d.kpis.returning_clients }}</strong></div>
          <div class="card stat"><small>Clients de passage</small><strong>{{ d.kpis.anonymous_washes }}</strong></div>
          <div class="card stat"><small>Récompenses remises</small><strong>{{ d.kpis.redemptions['used'] || 0 }}</strong></div>
          <div class="card stat"><small>Récompenses en attente</small><strong>{{ d.kpis.redemptions['pending'] || 0 }}</strong></div>
        </div>
      }
    </div>
  `,
  styles: [`
    .mt { margin-top: 20px; }
    .pad { padding: 18px 20px 4px; }
    .stat { small { color: var(--text-2); font-weight: 600; display: block; } strong { font-size: 24px; font-weight: 800; } }
  `],
})
export class ReportsComponent implements OnInit {
  private api = inject(CenterApi);
  periods = PERIODS;
  period = signal(29);
  from = daysAgo(29);
  to = isoDate(new Date());
  data = signal<Dashboard | null>(null);
  washers = signal<Dashboard['washers']>([]);

  servicesChart = computed<ChartConfiguration>(() => {
    const s = this.data()?.services ?? [];
    return {
      type: 'bar',
      data: { labels: s.map(x => x.name), datasets: [{ label: 'CA', data: s.map(x => x.revenue), backgroundColor: PALETTE, borderRadius: 8, maxBarThickness: 40 }] },
      options: { indexAxis: 'y', plugins: { legend: { display: false } }, scales: { x: { beginAtZero: true }, y: { grid: { display: false } } } },
    };
  });
  vehiclesChart = computed<ChartConfiguration>(() => {
    const v = this.data()?.vehicle_types ?? [];
    return {
      type: 'polarArea',
      data: { labels: v.map(x => x.name), datasets: [{ data: v.map(x => x.count), backgroundColor: PALETTE.map(c => c + 'cc'), borderWidth: 0 }] },
      options: { plugins: { legend: { position: 'right', labels: { usePointStyle: true, boxWidth: 8 } } } },
    };
  });

  ngOnInit(): void { this.load(); }
  setPeriod(days: number): void { this.period.set(days); this.from = daysAgo(days); this.to = isoDate(new Date()); this.load(); }

  load(): void {
    const p = { date_from: this.from, date_to: this.to };
    this.api.get<Dashboard>('/stats/dashboard', p).subscribe(d => this.data.set(d));
    this.api.get<{ washers: Dashboard['washers'] }>('/stats/washers', p).subscribe(r => this.washers.set(r.washers));
  }

  export(): void {
    this.api.blob('/washes/export', { date_from: this.from, date_to: this.to }).subscribe(b => download(b, `rapport_${this.from}_${this.to}.csv`));
  }
}
