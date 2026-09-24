import { AfterViewInit, Component, ElementRef, Input, OnChanges, OnDestroy, ViewChild } from '@angular/core';
import { Chart, ChartConfiguration, registerables } from 'chart.js';

Chart.register(...registerables);
Chart.defaults.font.family = "'Plus Jakarta Sans', system-ui, sans-serif";

@Component({
  selector: 'app-chart',
  standalone: true,
  template: `<div class="wrap" [style.height.px]="height"><canvas #canvas></canvas></div>`,
  styles: [`.wrap { position: relative; width: 100%; }`],
})
export class ChartComponent implements AfterViewInit, OnChanges, OnDestroy {
  @Input({ required: true }) config!: ChartConfiguration;
  @Input() height = 280;
  @ViewChild('canvas') canvas!: ElementRef<HTMLCanvasElement>;
  private chart?: Chart;

  ngAfterViewInit(): void { this.render(); }
  ngOnChanges(): void { if (this.canvas) this.render(); }
  ngOnDestroy(): void { this.chart?.destroy(); }

  private render(): void {
    this.chart?.destroy();
    const dark = matchMedia('(prefers-color-scheme: dark)').matches && document.documentElement.dataset['theme'] !== 'light'
      || document.documentElement.dataset['theme'] === 'dark';
    Chart.defaults.color = dark ? '#a8b3c7' : '#64748b';
    Chart.defaults.borderColor = dark ? 'rgba(148,163,184,.12)' : 'rgba(15,23,42,.06)';
    this.chart = new Chart(this.canvas.nativeElement, {
      ...this.config,
      options: { responsive: true, maintainAspectRatio: false, locale: 'fr-FR', ...this.config.options },
    });
  }
}

/** Dégradé vertical réutilisable pour les courbes. */
export function gradientFill(color: string) {
  return (ctx: { chart: Chart }) => {
    const { ctx: c, chartArea } = ctx.chart;
    if (!chartArea) return color;
    const g = c.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
    g.addColorStop(0, color.replace('1)', '.35)'));
    g.addColorStop(1, color.replace('1)', '0)'));
    return g;
  };
}

export const PALETTE = ['#2563eb', '#06b6d4', '#10b981', '#f59e0b', '#8b5cf6', '#ec4899', '#ef4444', '#84cc16', '#14b8a6', '#6366f1'];
