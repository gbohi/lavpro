import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ChartConfiguration } from 'chart.js';
import { AuthService } from '../../core/auth.service';
import { CenterApi } from '../../core/center-api.service';
import { Dashboard, Wash } from '../../core/models';
import { ChartComponent, PALETTE, gradientFill } from '../../shared/chart.component';
import { PERIODS, WEEKDAYS, daysAgo, isoDate } from '../../shared/period';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [ChartComponent, DecimalPipe, DatePipe, FormsModule, RouterLink],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss',
})
export class DashboardComponent implements OnInit {
  private api = inject(CenterApi);
  auth = inject(AuthService);
  periods = PERIODS;
  period = signal(29);
  from = daysAgo(29);
  to = isoDate(new Date());
  data = signal<Dashboard | null>(null);
  recent = signal<Wash[]>([]);

  greeting = (() => {
    const h = new Date().getHours();
    return h < 12 ? 'Bonjour' : h < 18 ? 'Bon après-midi' : 'Bonsoir';
  })();

  trend = computed<ChartConfiguration>(() => {
    const d = this.data();
    const rows = d?.washes_per_day ?? [];
    const fmt = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short' });
    return {
      type: 'line',
      data: {
        labels: rows.map(r => fmt.format(new Date(r.date))),
        datasets: [
          { label: 'Lavages', data: rows.map(r => r.washes), borderColor: '#2563eb', backgroundColor: gradientFill('rgba(37,99,235,1)') as never,
            fill: true, cubicInterpolationMode: 'monotone', pointRadius: 0, pointHoverRadius: 5, borderWidth: 2.5, yAxisID: 'y' },
          { label: `Chiffre d'affaires (${d?.currency ?? ''})`, data: rows.map(r => r.revenue), borderColor: '#06b6d4',
            borderDash: [6, 4], cubicInterpolationMode: 'monotone', pointRadius: 0, borderWidth: 2, yAxisID: 'y1' },
        ],
      },
      options: {
        interaction: { mode: 'index', intersect: false },
        plugins: { legend: { position: 'bottom', labels: { usePointStyle: true, boxWidth: 8 } } },
        scales: {
          x: { grid: { display: false }, ticks: { maxTicksLimit: 10 } },
          y: { beginAtZero: true, ticks: { precision: 0 } },
          y1: { beginAtZero: true, position: 'right', grid: { display: false } },
        },
      },
    };
  });

  services = computed<ChartConfiguration>(() => {
    const s = this.data()?.services ?? [];
    return {
      type: 'doughnut',
      data: { labels: s.map(x => x.name), datasets: [{ data: s.map(x => x.count), backgroundColor: PALETTE, borderWidth: 0, hoverOffset: 8 }] },
      options: { cutout: '72%', plugins: { legend: { position: 'bottom', labels: { usePointStyle: true, boxWidth: 8, padding: 14 } } } },
    };
  });

  hourly = computed<ChartConfiguration>(() => {
    const h = (this.data()?.hourly ?? []).slice(5, 23);
    return {
      type: 'bar',
      data: { labels: h.map(x => `${x.hour}h`), datasets: [{ label: 'Lavages', data: h.map(x => x.washes), backgroundColor: 'rgba(37,99,235,.85)', borderRadius: 6, maxBarThickness: 22 }] },
      options: { plugins: { legend: { display: false } }, scales: { x: { grid: { display: false } }, y: { beginAtZero: true, ticks: { precision: 0 } } } },
    };
  });

  weekdays = computed<ChartConfiguration>(() => {
    const w = this.data()?.weekdays ?? [];
    return {
      type: 'bar',
      data: { labels: w.map(x => WEEKDAYS[x.day].slice(0, 3)), datasets: [{ label: 'Lavages', data: w.map(x => x.washes), backgroundColor: 'rgba(6,182,212,.85)', borderRadius: 6, maxBarThickness: 28 }] },
      options: { plugins: { legend: { display: false } }, scales: { x: { grid: { display: false } }, y: { beginAtZero: true, ticks: { precision: 0 } } } },
    };
  });

  ngOnInit(): void { this.load(); }

  setPeriod(days: number): void {
    this.period.set(days);
    this.from = daysAgo(days);
    this.to = isoDate(new Date());
    this.load();
  }

  load(): void {
    this.api.get<Dashboard>('/stats/dashboard', { date_from: this.from, date_to: this.to }).subscribe(d => this.data.set(d));
    this.api.get<Wash[]>('/washes', { limit: 6 }).subscribe(w => this.recent.set(w));
  }
}
