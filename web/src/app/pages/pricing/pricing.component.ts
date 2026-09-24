import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { PricingRule } from '../../core/models';
import { ToastService } from '../../core/toast.service';

type Cell = { price: number | null; points: number | null; is_active: boolean };

@Component({
  selector: 'app-pricing',
  standalone: true,
  imports: [FormsModule, RouterLink],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Prix & points</h1><p class="muted">Pour chaque service et type de véhicule, fixez le prix et le nombre de points gagnés par le client.</p></div>
        <div class="row">
          <button class="btn" (click)="fillOpen.set(!fillOpen())"><span class="icon">auto_fix_high</span>Remplissage rapide</button>
          <button class="btn primary" [disabled]="!dirty()" (click)="save()"><span class="icon">save</span>Enregistrer</button>
        </div>
      </div>

      @if (fillOpen()) {
        <div class="card quick">
          <strong>Points automatiques :</strong>
          <span>1 point pour chaque</span>
          <input class="input" type="number" min="1" [(ngModel)]="ratio" style="width:120px">
          <span>{{ store.currency }} dépensés</span>
          <button class="btn primary sm" (click)="autoPoints()">Appliquer à toute la grille</button>
        </div>
      }

      @if (services().length && vehicles().length) {
        <div class="card flush">
          <div class="table-wrap">
            <table class="table matrix">
              <thead><tr><th>Service</th>@for (v of vehicles(); track v.id) { <th><span class="icon">{{ v.icon }}</span> {{ v.name }}</th> }</tr></thead>
              <tbody>
                @for (s of services(); track s.id) {
                  <tr>
                    <td class="svc"><span class="icon">{{ s.icon }}</span><strong>{{ s.name }}</strong></td>
                    @for (v of vehicles(); track v.id) {
                      <td>
                        <div class="cell" [class.empty-cell]="cell(s.id, v.id).price === null">
                          <label><span>{{ store.currency }}</span><input type="number" min="0" [ngModel]="cell(s.id, v.id).price" (ngModelChange)="set(s.id, v.id, 'price', $event)" placeholder="—"></label>
                          <label class="pts"><span>pts</span><input type="number" min="0" [ngModel]="cell(s.id, v.id).points" (ngModelChange)="set(s.id, v.id, 'points', $event)" placeholder="—"></label>
                        </div>
                      </td>
                    }
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </div>
        <p class="small muted" style="margin-top:12px">Une case vide signifie que la combinaison n'est pas proposée. Les promotions actives peuvent multiplier ces points.</p>
      } @else {
        <div class="card empty"><span class="icon">category</span>Ajoutez d'abord des services et des types de véhicules. <a routerLink="/catalog">Configurer →</a></div>
      }
    </div>
  `,
  styles: [`
    .quick { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 20px; }
    .matrix th { text-align: center; } .matrix th:first-child { text-align: left; }
    .svc { white-space: nowrap; .icon { color: var(--primary); margin-right: 8px; } }
    .cell { display: grid; gap: 6px; min-width: 150px;
      label { display: flex; align-items: center; border: 1px solid var(--border); border-radius: 10px; background: var(--surface-2); overflow: hidden; transition: .15s;
        &:focus-within { border-color: var(--primary); box-shadow: 0 0 0 3px var(--primary-soft); }
        span { padding: 0 10px; font-size: 11px; font-weight: 700; color: var(--muted); min-width: 44px; }
        input { flex: 1; width: 100%; border: none; background: transparent; height: 36px; font: 700 14px var(--font); color: var(--text); outline: none; text-align: right; padding-right: 10px; }
      }
      .pts { background: rgba(16,185,129,.07); span { color: #059669; } }
      &.empty-cell { opacity: .7; }
    }
  `],
})
export class PricingComponent implements OnInit {
  private api = inject(CenterApi);
  private toast = inject(ToastService);
  store = inject(CenterStore);
  grid = signal<Record<string, Cell>>({});
  dirty = signal(false);
  fillOpen = signal(false);
  ratio = 100;
  services = computed(() => this.store.services().filter(s => s.is_active));
  vehicles = computed(() => this.store.vehicleTypes().filter(v => v.is_active));

  ngOnInit(): void {
    this.api.get<PricingRule[]>('/pricing').subscribe(rules => {
      const g: Record<string, Cell> = {};
      rules.forEach(r => g[`${r.service_type_id}:${r.vehicle_type_id}`] = { price: r.price, points: r.points, is_active: r.is_active });
      this.grid.set(g);
    });
  }

  cell(s: number, v: number): Cell {
    return this.grid()[`${s}:${v}`] ?? { price: null, points: null, is_active: true };
  }

  set(s: number, v: number, key: 'price' | 'points', value: number | null): void {
    const k = `${s}:${v}`;
    this.grid.update(g => ({ ...g, [k]: { ...this.cell(s, v), [key]: value === null || (value as unknown) === '' ? null : Number(value) } }));
    this.dirty.set(true);
  }

  autoPoints(): void {
    if (!this.ratio || this.ratio <= 0) return;
    this.grid.update(g => {
      const next = { ...g };
      Object.entries(next).forEach(([k, c]) => { if (c.price !== null) next[k] = { ...c, points: Math.floor(c.price / this.ratio) }; });
      return next;
    });
    this.dirty.set(true);
  }

  save(): void {
    const rules = Object.entries(this.grid())
      .map(([k, c]) => {
        const [s, v] = k.split(':').map(Number);
        const filled = c.price !== null || c.points !== null;
        return { service_type_id: s, vehicle_type_id: v, price: c.price ?? 0, points: c.points ?? 0, is_active: filled };
      });
    this.api.put<PricingRule[]>('/pricing', { rules }).subscribe(() => { this.dirty.set(false); this.toast.success('Grille tarifaire enregistrée'); });
  }
}
