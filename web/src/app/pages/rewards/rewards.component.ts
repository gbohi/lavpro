import { DecimalPipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../core/api.service';
import { CenterApi } from '../../core/center-api.service';
import { Reward } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { ConfirmService } from '../../shared/confirm.service';
import { ModalComponent } from '../../shared/modal.component';

export const REWARD_CATEGORIES = [
  { value: 'wash', label: 'Lavage offert', icon: 'local_car_wash' },
  { value: 'fragrance', label: 'Senteur', icon: 'air' },
  { value: 'mat', label: 'Tapis', icon: 'dashboard' },
  { value: 'oil', label: "Bidon d'huile", icon: 'oil_barrel' },
  { value: 'discount', label: 'Réduction', icon: 'percent' },
  { value: 'eco', label: 'Offre écolo', icon: 'eco' },
  { value: 'gift', label: 'Cadeau', icon: 'redeem' },
];

type RewardForm = Omit<Reward, 'id' | 'center_id'> & { id?: number };

function blank(): RewardForm {
  return { name: '', description: '', category: 'wash', image_url: null, points_cost: 100, stock: null, eco_min_liters_saved: null,
    valid_from: null, valid_until: null, sort_order: 0, is_active: true };
}

@Component({
  selector: 'app-rewards',
  standalone: true,
  imports: [FormsModule, ModalComponent, DecimalPipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Récompenses</h1><p class="muted">Les cadeaux que vos clients débloquent avec leurs points. Entièrement personnalisables.</p></div>
        <button class="btn primary" (click)="edit()"><span class="icon">add</span>Nouvelle récompense</button>
      </div>
      <div class="rewards">
        @for (r of rewards(); track r.id) {
          <div class="card reward" [class.off]="!r.is_active">
            <div class="visual" [style.background-image]="r.image_url ? 'url(' + r.image_url + ')' : null">
              @if (!r.image_url) { <span class="icon">{{ icon(r.category) }}</span> }
              <span class="cost">{{ r.points_cost | number }} pts</span>
              @if (r.eco_min_liters_saved) { <span class="eco"><span class="icon">eco</span>{{ r.eco_min_liters_saved }} L</span> }
            </div>
            <div class="body">
              <h3>{{ r.name }}</h3>
              <p class="small muted">{{ r.description || catLabel(r.category) }}</p>
              <div class="actions">
                <span class="badge neutral">{{ r.stock === null ? 'Stock illimité' : r.stock + ' en stock' }}</span>
                <span class="spacer"></span>
                <label class="switch" title="Active"><input type="checkbox" [checked]="r.is_active" (change)="toggle(r)"><span class="track"></span></label>
                <button class="btn ghost icon-only sm" (click)="edit(r)"><span class="icon">edit</span></button>
                <button class="btn ghost icon-only sm" (click)="remove(r)"><span class="icon">delete</span></button>
              </div>
            </div>
          </div>
        } @empty {
          <div class="card empty span-all"><span class="icon">redeem</span>Créez votre première récompense pour motiver vos clients.</div>
        }
      </div>
    </div>

    <app-modal [open]="!!form()" [title]="form()?.id ? 'Modifier la récompense' : 'Nouvelle récompense'" [width]="620" (close)="form.set(null)">
      @if (form(); as f) {
        <div class="form-grid">
          <div class="field full"><label>Catégorie</label>
            <div class="chips">
              @for (c of categories; track c.value) {
                <button type="button" class="chip" [class.active]="f.category === c.value" (click)="f.category = c.value"><span class="icon">{{ c.icon }}</span>{{ c.label }}</button>
              }
            </div>
          </div>
          <div class="field full"><label>Nom *</label><input class="input" [(ngModel)]="f.name" placeholder="Ex : Lavage complet offert"></div>
          <div class="field full"><label>Description</label><textarea class="input" [(ngModel)]="f.description"></textarea></div>
          <div class="field"><label>Coût en points *</label><input class="input" type="number" min="1" [(ngModel)]="f.points_cost"></div>
          <div class="field"><label>Stock</label><input class="input" type="number" min="0" [(ngModel)]="f.stock" placeholder="Illimité"></div>
          <div class="field"><label>Valable du</label><input class="input" type="date" [ngModel]="f.valid_from?.slice(0,10)" (ngModelChange)="f.valid_from = $event || null"></div>
          <div class="field"><label>Au</label><input class="input" type="date" [ngModel]="f.valid_until?.slice(0,10)" (ngModelChange)="f.valid_until = $event || null"></div>
          <div class="field"><label>Mode Écolo : litres économisés requis</label><input class="input" type="number" min="0" [(ngModel)]="f.eco_min_liters_saved" placeholder="Aucun prérequis"><span class="hint">Réserve l'offre aux clients écoresponsables.</span></div>
          <div class="field"><label>Ordre d'affichage</label><input class="input" type="number" [(ngModel)]="f.sort_order"></div>
          <div class="field full"><label>Image</label>
            <div class="row">
              @if (f.image_url) { <img [src]="f.image_url" alt="" class="thumb"> }
              <label class="btn"><span class="icon">upload</span>Choisir une image<input type="file" accept="image/*" hidden (change)="upload($event, f)"></label>
              @if (f.image_url) { <button class="btn ghost" (click)="f.image_url = null">Retirer</button> }
            </div>
          </div>
          <label class="switch full"><input type="checkbox" [(ngModel)]="f.is_active"><span class="track"></span>Récompense active</label>
        </div>
      }
      <div modal-actions>
        <button class="btn" (click)="form.set(null)">Annuler</button>
        <button class="btn primary" [disabled]="!form()?.name || !form()?.points_cost" (click)="save()">Enregistrer</button>
      </div>
    </app-modal>
  `,
  styles: [`
    .rewards { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 20px; }
    .span-all { grid-column: 1 / -1; }
    .reward { padding: 0; overflow: hidden; transition: .2s; &:hover { transform: translateY(-3px); box-shadow: var(--shadow-lg); } &.off { opacity: .6; } }
    .visual { position: relative; height: 140px; background: var(--grad) center/cover; display: grid; place-items: center;
      > .icon { font-size: 64px; color: rgba(255,255,255,.9); }
      .cost { position: absolute; left: 12px; bottom: 12px; padding: 6px 12px; border-radius: 99px; background: rgba(2,6,23,.65); color: #fff; font-weight: 800; backdrop-filter: blur(6px); }
      .eco { position: absolute; right: 12px; top: 12px; display: flex; align-items: center; gap: 4px; padding: 4px 10px; border-radius: 99px; background: #10b981; color: #fff; font-weight: 700; font-size: 12px; .icon { font-size: 16px; } }
    }
    .body { padding: 16px 18px; }
    .actions { display: flex; align-items: center; gap: 6px; margin-top: 12px; }
    .thumb { width: 64px; height: 64px; object-fit: cover; border-radius: 10px; }
  `],
})
export class RewardsComponent implements OnInit {
  private api = inject(CenterApi);
  private root = inject(ApiService);
  private toast = inject(ToastService);
  private confirm = inject(ConfirmService);
  categories = REWARD_CATEGORIES;
  rewards = signal<Reward[]>([]);
  form = signal<RewardForm | null>(null);

  ngOnInit(): void { this.load(); }
  load(): void { this.api.get<Reward[]>('/rewards').subscribe(r => this.rewards.set(r)); }
  icon(c: string): string { return this.categories.find(x => x.value === c)?.icon ?? 'redeem'; }
  catLabel(c: string): string { return this.categories.find(x => x.value === c)?.label ?? c; }

  edit(r?: Reward): void { this.form.set(r ? { ...r } : blank()); }

  save(): void {
    const f = this.form();
    if (!f) return;
    const { id, ...body } = f;
    const req = id ? this.api.patch<Reward>(`/rewards/${id}`, body) : this.api.post<Reward>('/rewards', body);
    req.subscribe(() => { this.toast.success('Récompense enregistrée'); this.form.set(null); this.load(); });
  }

  toggle(r: Reward): void {
    this.api.patch<Reward>(`/rewards/${r.id}`, { is_active: !r.is_active }).subscribe(() => this.load());
  }

  async remove(r: Reward): Promise<void> {
    if (!await this.confirm.ask('Supprimer la récompense ?', `« ${r.name} » ne sera plus proposée aux clients.`, { danger: true, confirmLabel: 'Supprimer' })) return;
    this.api.delete(`/rewards/${r.id}`).subscribe(() => { this.toast.success('Récompense supprimée'); this.load(); });
  }

  upload(ev: Event, f: RewardForm): void {
    const file = (ev.target as HTMLInputElement).files?.[0];
    if (file) this.root.upload(file).subscribe(r => { f.image_url = r.url; this.form.set({ ...f }); });
  }
}
