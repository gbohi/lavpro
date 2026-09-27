import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { AuthService } from '../../core/auth.service';
import { AdminCenter, AppSetting, PlatformStats } from '../../core/models';
import { ToastService } from '../../core/toast.service';

interface EditableSetting extends AppSetting { draft: string; kind: 'bool' | 'number' | 'text' | 'json'; }

const GROUPS: Record<string, string> = {
  general: 'Général', referral: 'Parrainage', eco: 'Mode Écolo', reminders: 'Rappels intelligents',
  weather: 'Météo', booking: 'Réservation', team: 'Équipe', centers: 'Recherche de centres', onboarding: 'Modèles pour nouveaux centres',
};

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [FormsModule, DatePipe, DecimalPipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Administration de la plateforme</h1><p class="muted">Paramètres globaux, centres partenaires et tâches planifiées.</p></div>
        <button class="btn" (click)="runReminders()"><span class="icon">notifications_active</span>Lancer les tâches quotidiennes</button>
      </div>
      @if (stats(); as s) {
        <div class="grid grid-4">
          <div class="card kpi"><span class="kpi-icon"><span class="icon">storefront</span></span><div><div class="kpi-label">Centres</div><div class="kpi-value">{{ s.active_centers }}/{{ s.centers }}</div></div></div>
          <div class="card kpi"><span class="kpi-icon eco"><span class="icon">groups</span></span><div><div class="kpi-label">Clients</div><div class="kpi-value">{{ s.clients | number }}</div></div></div>
          <div class="card kpi"><span class="kpi-icon violet"><span class="icon">local_car_wash</span></span><div><div class="kpi-label">Lavages (30 j)</div><div class="kpi-value">{{ s.washes_30d | number }}</div><div class="kpi-sub">{{ s.washes | number }} au total</div></div></div>
          <div class="card kpi"><span class="kpi-icon warm"><span class="icon">stars</span></span><div><div class="kpi-label">Points distribués</div><div class="kpi-value">{{ s.points_issued | number }}</div></div></div>
        </div>
      }

      <div class="card flush mt">
        <div class="card-head pad"><h2>Centres partenaires</h2></div>
        <div class="table-wrap">
          <table class="table">
            <thead><tr><th>Centre</th><th>Propriétaire</th><th class="num">Clients</th><th class="num">Lavages</th><th>Inscrit le</th><th>Statut</th><th></th></tr></thead>
            <tbody>
              @for (c of centers(); track c.id) {
                <tr>
                  <td><strong>{{ c.name }}</strong><div class="small muted">{{ c.city }}</div></td>
                  <td class="small">{{ c.owner_email }}</td>
                  <td class="num">{{ c.clients_count }}</td>
                  <td class="num">{{ c.washes_count }}</td>
                  <td>{{ c.created_at | date:'dd/MM/yyyy' }}</td>
                  <td><label class="switch"><input type="checkbox" [checked]="c.is_active" (change)="toggle(c)"><span class="track"></span>{{ c.is_active ? 'Actif' : 'Suspendu' }}</label></td>
                  <td class="num"><button class="btn sm" (click)="open(c)">Ouvrir</button></td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </div>

      <h2 class="mt">Paramètres globaux</h2>
      <p class="muted small" style="margin:4px 0 16px">Aucune valeur n'est figée : ces paramètres pilotent le comportement de toute la plateforme.</p>
      <div class="grid grid-2">
        @for (g of groups(); track g.key) {
          <div class="card">
            <div class="card-head"><h3>{{ groupLabel(g.key) }}</h3></div>
            @for (s of g.items; track s.key) {
              <div class="setting">
                <label>{{ s.label }} <code>{{ s.key }}</code></label>
                @if (s.description) { <div class="hint">{{ s.description }}</div> }
                <div class="row">
                  @switch (s.kind) {
                    @case ('bool') { <label class="switch" style="flex:1"><input type="checkbox" [checked]="s.draft === 'true'" (change)="s.draft = s.draft === 'true' ? 'false' : 'true'"><span class="track"></span>{{ s.draft === 'true' ? 'Activé' : 'Désactivé' }}</label> }
                    @case ('json') { <textarea class="input mono" rows="5" [(ngModel)]="s.draft" style="flex:1"></textarea> }
                    @case ('number') { <input class="input" type="number" step="any" [(ngModel)]="s.draft" style="flex:1"> }
                    @default { <input class="input" [(ngModel)]="s.draft" style="flex:1"> }
                  }
                  <button class="btn sm primary" (click)="saveSetting(s)">OK</button>
                </div>
              </div>
            }
          </div>
        }
      </div>
    </div>
  `,
  styles: [`
    .mt { margin-top: 24px; }
    .pad { padding: 18px 20px 4px; }
    .setting { padding: 12px 0; border-bottom: 1px dashed var(--border); &:last-child { border-bottom: none; }
      > label { font-weight: 700; font-size: 13px; display: block; margin-bottom: 6px; code { font-size: 11px; color: var(--muted); font-weight: 500; margin-left: 6px; } }
      .hint { font-size: 12px; color: var(--muted); margin: -2px 0 6px; }
    }
    .mono { font-family: ui-monospace, 'SF Mono', Menlo, monospace; font-size: 12px; }
  `],
})
export class AdminComponent implements OnInit {
  private api = inject(ApiService);
  private auth = inject(AuthService);
  private router = inject(Router);
  private toast = inject(ToastService);
  stats = signal<PlatformStats | null>(null);
  centers = signal<AdminCenter[]>([]);
  settings = signal<EditableSetting[]>([]);
  groups = computed(() => {
    const map = new Map<string, EditableSetting[]>();
    this.settings().forEach(s => map.set(s.group, [...(map.get(s.group) ?? []), s]));
    return [...map.entries()].map(([key, items]) => ({ key, items }));
  });

  ngOnInit(): void {
    this.api.get<PlatformStats>('/admin/stats').subscribe(s => this.stats.set(s));
    this.loadCenters();
    this.api.get<AppSetting[]>('/admin/settings').subscribe(list => this.settings.set(list.map(s => this.editable(s))));
  }

  groupLabel(k: string): string { return GROUPS[k] ?? k; }
  loadCenters(): void { this.api.get<AdminCenter[]>('/admin/centers').subscribe(c => this.centers.set(c)); }

  private editable(s: AppSetting): EditableSetting {
    const v = s.value;
    const kind = typeof v === 'boolean' ? 'bool' : typeof v === 'number' ? 'number' : typeof v === 'string' ? 'text' : 'json';
    return { ...s, kind, draft: kind === 'json' ? JSON.stringify(v, null, 2) : String(v) };
  }

  saveSetting(s: EditableSetting): void {
    let value: unknown;
    try {
      value = s.kind === 'bool' ? s.draft === 'true' : s.kind === 'number' ? Number(s.draft) : s.kind === 'json' ? JSON.parse(s.draft) : s.draft;
    } catch {
      this.toast.error('JSON invalide');
      return;
    }
    this.api.put<AppSetting>(`/admin/settings/${s.key}`, { value }).subscribe(() => this.toast.success('Paramètre enregistré'));
  }

  toggle(c: AdminCenter): void { this.api.post(`/admin/centers/${c.id}/toggle`).subscribe(() => this.loadCenters()); }
  open(c: AdminCenter): void { this.auth.selectCenter(c.id); this.router.navigate(['/dashboard']); }
  runReminders(): void {
    this.api.post<{ wash_reminders: number; expiry_reminders: number; points_expired: number }>('/admin/jobs/reminders').subscribe(r =>
      this.toast.success(`${r.wash_reminders} rappel(s) de lavage, ${r.expiry_reminders} relance(s) d'expiration, ${r.points_expired} point(s) expiré(s)`));
  }
}
