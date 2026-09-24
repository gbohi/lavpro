import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { ServiceType, VehicleType } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { ConfirmService } from '../../shared/confirm.service';
import { ModalComponent } from '../../shared/modal.component';

const VEHICLE_ICONS = ['directions_car', 'airport_shuttle', 'two_wheeler', 'local_shipping', 'fire_truck', 'agriculture', 'directions_bus', 'electric_car', 'rv_hookup', 'pedal_bike'];
const SERVICE_ICONS = ['local_car_wash', 'auto_awesome', 'settings', 'eco', 'water_drop', 'cleaning_services', 'dry_cleaning', 'tire_repair', 'airline_seat_recline_extra', 'wash', 'bubble_chart', 'star'];

type Kind = 'service' | 'vehicle';

@Component({
  selector: 'app-catalog',
  standalone: true,
  imports: [FormsModule, ModalComponent],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Services & types de véhicules</h1><p class="muted">Définissez librement vos prestations et catégories de véhicules. Les prix et points se règlent dans « Prix & points ».</p></div>
      </div>
      <div class="grid grid-2">
        <div class="card">
          <div class="card-head"><h2>Services</h2><button class="btn primary sm" (click)="editService()"><span class="icon">add</span>Ajouter</button></div>
          @for (s of store.services(); track s.id) {
            <div class="list-item" [class.off]="!s.is_active">
              <span class="ico"><span class="icon">{{ s.icon }}</span></span>
              <div style="flex:1">
                <strong>{{ s.name }}</strong> @if (s.is_eco) { <span class="badge success"><span class="icon">eco</span>Écolo</span> }
                <div class="small muted">{{ s.duration_minutes }} min · {{ s.water_used_liters }} L d'eau @if (!s.bookable) { · non réservable }</div>
              </div>
              <button class="btn ghost icon-only sm" (click)="editService(s)"><span class="icon">edit</span></button>
              <button class="btn ghost icon-only sm" (click)="remove('service', s.id, s.name)"><span class="icon">delete</span></button>
            </div>
          } @empty { <div class="empty">Aucun service</div> }
        </div>
        <div class="card">
          <div class="card-head"><h2>Types de véhicules</h2><button class="btn primary sm" (click)="editVehicle()"><span class="icon">add</span>Ajouter</button></div>
          @for (v of store.vehicleTypes(); track v.id) {
            <div class="list-item" [class.off]="!v.is_active">
              <span class="ico alt"><span class="icon">{{ v.icon }}</span></span>
              <div style="flex:1"><strong>{{ v.name }}</strong><div class="small muted">Référence Mode Écolo : {{ v.eco_baseline_liters }} L / lavage classique</div></div>
              <button class="btn ghost icon-only sm" (click)="editVehicle(v)"><span class="icon">edit</span></button>
              <button class="btn ghost icon-only sm" (click)="remove('vehicle', v.id, v.name)"><span class="icon">delete</span></button>
            </div>
          } @empty { <div class="empty">Aucun type de véhicule</div> }
        </div>
      </div>
      <div class="card tip">
        <span class="icon filled">eco</span>
        <p><strong>Mode Écolo :</strong> l'eau économisée par lavage = référence du type de véhicule − eau consommée par le service. Ce total alimente les niveaux écolo des clients et débloque vos offres écoresponsables.</p>
      </div>
    </div>

    <app-modal [open]="!!service()" [title]="service()?.id ? 'Modifier le service' : 'Nouveau service'" (close)="service.set(null)">
      @if (service(); as s) {
        <div class="form-grid">
          <div class="field full"><label>Nom *</label><input class="input" [(ngModel)]="s.name" placeholder="Ex : Lavage complet"></div>
          <div class="field full"><label>Description</label><textarea class="input" [(ngModel)]="s.description"></textarea></div>
          <div class="field full"><label>Icône</label><div class="icons">@for (i of serviceIcons; track i) { <button type="button" [class.active]="s.icon === i" (click)="s.icon = i"><span class="icon">{{ i }}</span></button> }</div></div>
          <div class="field"><label>Durée (minutes)</label><input class="input" type="number" min="1" [(ngModel)]="s.duration_minutes"></div>
          <div class="field"><label>Eau consommée (L)</label><input class="input" type="number" min="0" [(ngModel)]="s.water_used_liters"></div>
          <div class="field"><label>Ordre</label><input class="input" type="number" [(ngModel)]="s.sort_order"></div>
          <div></div>
          <label class="switch"><input type="checkbox" [(ngModel)]="s.is_eco"><span class="track"></span>Service écologique</label>
          <label class="switch"><input type="checkbox" [(ngModel)]="s.bookable"><span class="track"></span>Réservable en ligne</label>
          <label class="switch"><input type="checkbox" [(ngModel)]="s.is_active"><span class="track"></span>Actif</label>
        </div>
      }
      <div modal-actions><button class="btn" (click)="service.set(null)">Annuler</button><button class="btn primary" [disabled]="!service()?.name" (click)="saveService()">Enregistrer</button></div>
    </app-modal>

    <app-modal [open]="!!vehicle()" [title]="vehicle()?.id ? 'Modifier le type' : 'Nouveau type de véhicule'" (close)="vehicle.set(null)">
      @if (vehicle(); as v) {
        <div class="form-grid">
          <div class="field full"><label>Nom *</label><input class="input" [(ngModel)]="v.name" placeholder="Ex : 4x4"></div>
          <div class="field full"><label>Icône</label><div class="icons">@for (i of vehicleIcons; track i) { <button type="button" [class.active]="v.icon === i" (click)="v.icon = i"><span class="icon">{{ i }}</span></button> }</div></div>
          <div class="field"><label>Eau d'un lavage classique (L)</label><input class="input" type="number" min="0" [(ngModel)]="v.eco_baseline_liters"></div>
          <div class="field"><label>Ordre</label><input class="input" type="number" [(ngModel)]="v.sort_order"></div>
          <label class="switch"><input type="checkbox" [(ngModel)]="v.is_active"><span class="track"></span>Actif</label>
        </div>
      }
      <div modal-actions><button class="btn" (click)="vehicle.set(null)">Annuler</button><button class="btn primary" [disabled]="!vehicle()?.name" (click)="saveVehicle()">Enregistrer</button></div>
    </app-modal>
  `,
  styles: [`
    .off { opacity: .5; }
    .ico { width: 42px; height: 42px; border-radius: 12px; display: grid; place-items: center; background: var(--primary-soft); color: var(--primary); &.alt { background: rgba(6,182,212,.12); color: #0891b2; } }
    .icons { display: flex; flex-wrap: wrap; gap: 8px;
      button { width: 42px; height: 42px; border-radius: 10px; border: 1px solid var(--border); background: var(--surface-2); color: var(--text-2); cursor: pointer; }
      button.active { background: var(--grad); color: #fff; border-color: transparent; }
    }
    .tip { margin-top: 20px; display: flex; gap: 14px; align-items: flex-start; background: rgba(16,185,129,.08); border-color: rgba(16,185,129,.25); .icon { color: var(--success); font-size: 26px; } }
  `],
})
export class CatalogComponent {
  private api = inject(CenterApi);
  private toast = inject(ToastService);
  private confirm = inject(ConfirmService);
  store = inject(CenterStore);
  vehicleIcons = VEHICLE_ICONS;
  serviceIcons = SERVICE_ICONS;
  service = signal<Partial<ServiceType> | null>(null);
  vehicle = signal<Partial<VehicleType> | null>(null);

  editService(s?: ServiceType): void {
    this.service.set(s ? { ...s } : { name: '', description: '', icon: 'local_car_wash', duration_minutes: 30, water_used_liters: 0, is_eco: false, bookable: true, sort_order: this.store.services().length, is_active: true });
  }
  editVehicle(v?: VehicleType): void {
    this.vehicle.set(v ? { ...v } : { name: '', icon: 'directions_car', eco_baseline_liters: 0, sort_order: this.store.vehicleTypes().length, is_active: true });
  }

  saveService(): void {
    const { id, center_id, ...body } = this.service()!;
    const req = id ? this.api.patch(`/services/${id}`, body) : this.api.post('/services', body);
    req.subscribe(() => { this.toast.success('Service enregistré'); this.service.set(null); this.store.refreshCatalog(); });
  }
  saveVehicle(): void {
    const { id, center_id, ...body } = this.vehicle()!;
    const req = id ? this.api.patch(`/vehicle-types/${id}`, body) : this.api.post('/vehicle-types', body);
    req.subscribe(() => { this.toast.success('Type de véhicule enregistré'); this.vehicle.set(null); this.store.refreshCatalog(); });
  }

  async remove(kind: Kind, id: number, name: string): Promise<void> {
    if (!await this.confirm.ask(`Supprimer « ${name} » ?`, "S'il a déjà été utilisé, il sera simplement désactivé pour conserver l'historique.", { danger: true, confirmLabel: 'Supprimer' })) return;
    this.api.delete(kind === 'service' ? `/services/${id}` : `/vehicle-types/${id}`).subscribe(() => { this.toast.success('Supprimé'); this.store.refreshCatalog(); });
  }
}
