import { DatePipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { Promotion, PromotionTarget } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { ConfirmService } from '../../shared/confirm.service';
import { ModalComponent } from '../../shared/modal.component';

type PromoForm = Omit<Promotion, 'id' | 'center_id'> & { id?: number };

function local(d: Date): string {
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
}

@Component({
  selector: 'app-promotions',
  standalone: true,
  imports: [FormsModule, ModalComponent, DatePipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Promotions</h1><p class="muted">Points multipliés, bonus ou remises, ciblés sur les bons clients au bon moment.</p></div>
        <button class="btn primary" (click)="edit()"><span class="icon">add</span>Nouvelle promotion</button>
      </div>
      <div class="grid grid-3">
        @for (p of promos(); track p.id) {
          <div class="card promo">
            <div class="row">
              <span class="badge {{ state(p).cls }}">{{ state(p).label }}</span>
              <span class="badge neutral"><span class="icon">{{ targetIcon(p.target) }}</span>{{ targetLabel(p.target) }}</span>
              <span class="spacer"></span>
              <button class="btn ghost icon-only sm" (click)="edit(p)"><span class="icon">edit</span></button>
              <button class="btn ghost icon-only sm" (click)="remove(p)"><span class="icon">delete</span></button>
            </div>
            <h2 style="margin-top:12px">{{ p.name }}</h2>
            <p class="small muted">{{ p.description }}</p>
            <div class="perks">
              @if (p.points_multiplier !== 1) { <span><b>×{{ p.points_multiplier }}</b> points</span> }
              @if (p.bonus_points) { <span><b>+{{ p.bonus_points }}</b> pts bonus</span> }
              @if (p.discount_percent) { <span><b>-{{ p.discount_percent }} %</b> remise</span> }
            </div>
            <div class="small muted"><span class="icon" style="font-size:16px">schedule</span> {{ p.starts_at | date:'dd/MM HH:mm' }} → {{ p.ends_at | date:'dd/MM/yy HH:mm' }}</div>
            @if (p.service_type_id || p.vehicle_type_id) {
              <div class="small" style="margin-top:6px">Limité à : {{ serviceName(p.service_type_id) }} {{ vehicleName(p.vehicle_type_id) }}</div>
            }
          </div>
        } @empty {
          <div class="card empty" style="grid-column:1/-1"><span class="icon">campaign</span>Aucune promotion. Lancez-en une pour booster une journée creuse !</div>
        }
      </div>
    </div>

    <app-modal [open]="!!form()" [title]="form()?.id ? 'Modifier la promotion' : 'Nouvelle promotion'" [width]="640" (close)="form.set(null)">
      @if (form(); as f) {
        <div class="form-grid">
          <div class="field full"><label>Nom *</label><input class="input" [(ngModel)]="f.name" placeholder="Ex : Mardi double points"></div>
          <div class="field full"><label>Message aux clients</label><textarea class="input" [(ngModel)]="f.description"></textarea></div>
          <div class="field"><label>Multiplicateur de points</label><input class="input" type="number" step="0.1" min="0" [(ngModel)]="f.points_multiplier"></div>
          <div class="field"><label>Points bonus</label><input class="input" type="number" min="0" [(ngModel)]="f.bonus_points"></div>
          <div class="field"><label>Remise (%)</label><input class="input" type="number" min="0" max="100" [(ngModel)]="f.discount_percent"></div>
          <div class="field"><label>Clients ciblés</label>
            <select class="input" [(ngModel)]="f.target">@for (t of targets; track t.value) { <option [value]="t.value">{{ t.label }}</option> }</select>
          </div>
          <div class="field"><label>Service</label>
            <select class="input" [(ngModel)]="f.service_type_id"><option [ngValue]="null">Tous</option>
              @for (s of store.services(); track s.id) { <option [ngValue]="s.id">{{ s.name }}</option> }</select>
          </div>
          <div class="field"><label>Type de véhicule</label>
            <select class="input" [(ngModel)]="f.vehicle_type_id"><option [ngValue]="null">Tous</option>
              @for (v of store.vehicleTypes(); track v.id) { <option [ngValue]="v.id">{{ v.name }}</option> }</select>
          </div>
          <div class="field"><label>Début *</label><input class="input" type="datetime-local" [(ngModel)]="f.starts_at"></div>
          <div class="field"><label>Fin *</label><input class="input" type="datetime-local" [(ngModel)]="f.ends_at"></div>
          @if (!f.id) { <label class="switch full"><input type="checkbox" [(ngModel)]="f.notify_clients"><span class="track"></span>Notifier les clients ciblés</label> }
          <label class="switch full"><input type="checkbox" [(ngModel)]="f.is_active"><span class="track"></span>Promotion active</label>
        </div>
      }
      <div modal-actions>
        <button class="btn" (click)="form.set(null)">Annuler</button>
        <button class="btn primary" [disabled]="!form()?.name" (click)="save()">Enregistrer</button>
      </div>
    </app-modal>
  `,
  styles: [`
    .promo { display: flex; flex-direction: column; gap: 4px; }
    .perks { display: flex; gap: 8px; flex-wrap: wrap; margin: 14px 0 10px;
      span { padding: 8px 12px; border-radius: 12px; background: var(--primary-soft); font-size: 13px; b { color: var(--primary); font-size: 16px; } }
    }
  `],
})
export class PromotionsComponent implements OnInit {
  private api = inject(CenterApi);
  private toast = inject(ToastService);
  private confirm = inject(ConfirmService);
  store = inject(CenterStore);
  promos = signal<Promotion[]>([]);
  form = signal<PromoForm | null>(null);
  targets: { value: PromotionTarget; label: string; icon: string }[] = [
    { value: 'all', label: 'Tous les clients', icon: 'groups' },
    { value: 'loyal', label: 'Clients fidèles', icon: 'workspace_premium' },
    { value: 'new', label: 'Nouveaux clients', icon: 'fiber_new' },
    { value: 'inactive', label: 'Clients inactifs', icon: 'bedtime' },
  ];

  ngOnInit(): void { this.load(); }
  load(): void { this.api.get<Promotion[]>('/promotions').subscribe(p => this.promos.set(p)); }
  targetLabel(t: string): string { return this.targets.find(x => x.value === t)?.label ?? t; }
  targetIcon(t: string): string { return this.targets.find(x => x.value === t)?.icon ?? 'groups'; }
  serviceName(id: number | null): string { return id ? this.store.services().find(s => s.id === id)?.name ?? '' : ''; }
  vehicleName(id: number | null): string { return id ? this.store.vehicleTypes().find(s => s.id === id)?.name ?? '' : ''; }

  state(p: Promotion): { label: string; cls: string } {
    const now = Date.now();
    if (!p.is_active) return { label: 'Désactivée', cls: 'neutral' };
    if (new Date(p.ends_at).getTime() < now) return { label: 'Terminée', cls: 'neutral' };
    if (new Date(p.starts_at).getTime() > now) return { label: 'À venir', cls: 'warning' };
    return { label: 'En cours', cls: 'success' };
  }

  edit(p?: Promotion): void {
    if (p) {
      this.form.set({ ...p, starts_at: local(new Date(p.starts_at)), ends_at: local(new Date(p.ends_at)) });
    } else {
      const start = new Date();
      const end = new Date(Date.now() + 7 * 86400000);
      this.form.set({ name: '', description: '', points_multiplier: 2, bonus_points: 0, discount_percent: 0, service_type_id: null,
        vehicle_type_id: null, target: 'all', starts_at: local(start), ends_at: local(end), notify_clients: true, is_active: true });
    }
  }

  save(): void {
    const f = this.form();
    if (!f) return;
    const { id, ...rest } = f;
    const body = { ...rest, starts_at: new Date(f.starts_at).toISOString(), ends_at: new Date(f.ends_at).toISOString() };
    const req = id ? this.api.patch(`/promotions/${id}`, body) : this.api.post('/promotions', body);
    req.subscribe(() => { this.toast.success('Promotion enregistrée'); this.form.set(null); this.load(); });
  }

  async remove(p: Promotion): Promise<void> {
    if (!await this.confirm.ask('Supprimer la promotion ?', p.name, { danger: true, confirmLabel: 'Supprimer' })) return;
    this.api.delete(`/promotions/${p.id}`).subscribe(() => this.load());
  }
}
