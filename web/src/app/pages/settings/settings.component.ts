import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../core/api.service';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { Center } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { WEEKDAYS } from '../../shared/period';

type Tab = 'info' | 'hours' | 'booking' | 'loyalty' | 'reminders';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Paramètres du centre</h1><p class="muted">Tout est personnalisable : informations, horaires, réservation, fidélité et rappels.</p></div>
        <button class="btn primary" (click)="save()" [disabled]="!c()"><span class="icon">save</span>Enregistrer</button>
      </div>
      <div class="tabs">
        @for (t of tabs; track t.id) {
          <button class="chip" [class.active]="tab() === t.id" (click)="tab.set(t.id)"><span class="icon">{{ t.icon }}</span>{{ t.label }}</button>
        }
      </div>

      @if (c(); as c) {
        @switch (tab()) {
          @case ('info') {
            <div class="card">
              <div class="brand-row">
                <div class="logo" [style.background-image]="c.logo_url ? 'url(' + c.logo_url + ')' : null">@if (!c.logo_url) { <span class="icon">storefront</span> }</div>
                <div>
                  <label class="btn sm"><span class="icon">upload</span>Logo<input type="file" accept="image/*" hidden (change)="upload($event, 'logo_url')"></label>
                  <label class="btn sm" style="margin-left:8px"><span class="icon">image</span>Photo de couverture<input type="file" accept="image/*" hidden (change)="upload($event, 'cover_url')"></label>
                  <p class="small muted" style="margin-top:6px">Affichés dans l'application mobile des clients.</p>
                </div>
              </div>
              <div class="form-grid" style="margin-top:20px">
                <div class="field"><label>Nom du centre</label><input class="input" [(ngModel)]="c.name"></div>
                <div class="field"><label>Téléphone</label><input class="input" [(ngModel)]="c.phone"></div>
                <div class="field full"><label>Description</label><textarea class="input" [(ngModel)]="c.description"></textarea></div>
                <div class="field full"><label>Adresse</label><input class="input" [(ngModel)]="c.address"></div>
                <div class="field"><label>Ville</label><input class="input" [(ngModel)]="c.city"></div>
                <div class="field"><label>Pays</label><input class="input" [(ngModel)]="c.country"></div>
                <div class="field"><label>E-mail</label><input class="input" type="email" [(ngModel)]="c.email"></div>
                <div class="field"><label>Devise</label><input class="input" [(ngModel)]="c.currency"></div>
                <div class="field"><label>Fuseau horaire</label><input class="input" [(ngModel)]="c.timezone" placeholder="Africa/Abidjan"></div>
                <div class="field"><label>Coordonnées GPS</label>
                  <div class="row"><input class="input" type="number" step="any" [(ngModel)]="c.lat" placeholder="Latitude" style="flex:1"><input class="input" type="number" step="any" [(ngModel)]="c.lng" placeholder="Longitude" style="flex:1">
                  <button class="btn icon-only" title="Ma position" (click)="locate(c)"><span class="icon">my_location</span></button></div>
                </div>
              </div>
            </div>
          }
          @case ('hours') {
            <div class="card">
              @for (d of c.opening_hours; track d.day) {
                <div class="day">
                  <strong>{{ weekdays[d.day] }}</strong>
                  <label class="switch"><input type="checkbox" [checked]="!d.closed" (change)="d.closed = !d.closed"><span class="track"></span>{{ d.closed ? 'Fermé' : 'Ouvert' }}</label>
                  @if (!d.closed) {
                    <input class="input" type="time" [(ngModel)]="d.open"><span class="muted">→</span><input class="input" type="time" [(ngModel)]="d.close">
                  }
                </div>
              }
            </div>
          }
          @case ('booking') {
            <div class="card form-grid">
              <label class="switch full"><input type="checkbox" [(ngModel)]="c.booking_enabled"><span class="track"></span>Autoriser la réservation de créneaux</label>
              <div class="field"><label>Postes de lavage simultanés</label><input class="input" type="number" min="1" [(ngModel)]="c.capacity"><span class="hint">Capacité utilisée pour les créneaux et l'affluence.</span></div>
              <div class="field"><label>Durée d'un créneau (min)</label><input class="input" type="number" min="5" [(ngModel)]="c.slot_duration_minutes"></div>
              <div class="field"><label>Délai minimum avant réservation (min)</label><input class="input" type="number" min="0" [(ngModel)]="c.booking_min_notice_minutes"></div>
              <div class="field"><label>Réservation jusqu'à (jours)</label><input class="input" type="number" min="0" [(ngModel)]="c.booking_max_days_ahead"></div>
              <div class="field"><label>Affluence « modérée » à partir de (ratio file/capacité)</label><input class="input" type="number" step="0.1" min="0" [(ngModel)]="c.occupancy_moderate_ratio"></div>
              <div class="field"><label>Affluence « forte » à partir de</label><input class="input" type="number" step="0.1" min="0" [(ngModel)]="c.occupancy_high_ratio"></div>
            </div>
          }
          @case ('loyalty') {
            <div class="card form-grid">
              <div class="field"><label>Points de bienvenue</label><input class="input" type="number" min="0" [(ngModel)]="c.welcome_points"><span class="hint">Offerts à la première visite d'un client.</span></div>
              <div></div>
              <div class="field"><label>Parrainage : points du parrain</label><input class="input" type="number" min="0" [(ngModel)]="c.referral_referrer_points"></div>
              <div class="field"><label>Parrainage : points du filleul</label><input class="input" type="number" min="0" [(ngModel)]="c.referral_referee_points"><span class="hint">Crédités au premier lavage du filleul dans votre centre.</span></div>
              <div class="field"><label>Client fidèle : visites minimum</label><input class="input" type="number" min="1" [(ngModel)]="c.loyal_min_visits"></div>
              <div class="field"><label>… sur une période de (jours)</label><input class="input" type="number" min="1" [(ngModel)]="c.loyal_period_days"></div>
              <div class="field"><label>Client inactif après (jours sans visite)</label><input class="input" type="number" min="1" [(ngModel)]="c.inactive_after_days"></div>
              <div class="field full expiry">
                <label>Durée de validité des points</label>
                <div class="row">
                  <select class="input" style="width:auto" [ngModel]="c.points_validity_months ? 'on' : 'off'"
                    (ngModelChange)="c.points_validity_months = $event === 'on' ? (c.points_validity_months || 12) : null">
                    <option value="off">Pas d'expiration</option>
                    <option value="on">Les points expirent</option>
                  </select>
                  @if (c.points_validity_months) {
                    <input class="input" type="number" min="1" max="120" style="width:100px" [(ngModel)]="c.points_validity_months">
                    <span>mois après avoir été gagnés</span>
                  }
                </div>
                <span class="hint">Chaque gain de points a sa propre date d'expiration ; les points qui expirent le plus tôt sont utilisés en premier.
                  En activant l'expiration, les points déjà gagnés reçoivent la durée complète à partir d'aujourd'hui.</span>
                @if (c.points_validity_months) {
                  <label style="margin-top:12px">Relances avant expiration (jours, séparés par des virgules)</label>
                  <input class="input" style="max-width:260px" [ngModel]="c.points_expiry_reminders.join(', ')" (ngModelChange)="setReminders(c, $event)" placeholder="30, 7">
                  <span class="hint">Le client reçoit une notification « Vos points vont expirer » à chacun de ces délais, puis une notification lorsque des points ont expiré.</span>
                }
              </div>
              <div class="field full">
                <label class="switch"><input type="checkbox" [(ngModel)]="c.points_payment_enabled"><span class="track"></span>Autoriser le paiement d'un lavage directement en points au comptoir</label>
                <span class="hint">Le nombre de points à dépenser se règle pour chaque service et véhicule dans « Prix &amp; points » (ligne « payer »).</span>
              </div>
            </div>
          }
          @case ('reminders') {
            <div class="card form-grid">
              <label class="switch full"><input type="checkbox" [(ngModel)]="c.reminder_enabled"><span class="track"></span>Envoyer des rappels intelligents à mes clients</label>
              <div class="field"><label>Fréquence par défaut (jours)</label><input class="input" type="number" min="1" [(ngModel)]="c.reminder_default_days"><span class="hint">Utilisée tant que la fréquence réelle du client n'est pas connue.</span></div>
              <p class="full muted small">Lavpro analyse la fréquence de visite de chaque client et la météo prévue autour de votre centre pour lui suggérer de revenir au moment idéal (pas de rappel s'il va pleuvoir).</p>
            </div>
          }
        }
      }
    </div>
  `,
  styles: [`
    .tabs { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 20px; }
    .brand-row { display: flex; gap: 18px; align-items: center; flex-wrap: wrap; }
    .expiry { padding: 14px; border-radius: 14px; background: var(--surface-2); border: 1px solid var(--border); }
    .logo { width: 84px; height: 84px; border-radius: 22px; background: var(--grad) center/cover; display: grid; place-items: center; box-shadow: var(--shadow); .icon { color: #fff; font-size: 38px; } }
    .day { display: flex; align-items: center; gap: 14px; padding: 12px 0; border-bottom: 1px dashed var(--border); flex-wrap: wrap;
      &:last-child { border-bottom: none; }
      strong { width: 100px; }
      .switch { width: 110px; }
      .input { width: 130px; }
    }
  `],
})
export class SettingsComponent implements OnInit {
  private api = inject(CenterApi);
  private root = inject(ApiService);
  private toast = inject(ToastService);
  private store = inject(CenterStore);
  weekdays = WEEKDAYS;
  tab = signal<Tab>('info');
  c = signal<Center | null>(null);
  tabs: { id: Tab; label: string; icon: string }[] = [
    { id: 'info', label: 'Informations', icon: 'storefront' },
    { id: 'hours', label: 'Horaires', icon: 'schedule' },
    { id: 'booking', label: 'Réservation & affluence', icon: 'event_available' },
    { id: 'loyalty', label: 'Fidélité & parrainage', icon: 'loyalty' },
    { id: 'reminders', label: 'Rappels', icon: 'notifications_active' },
  ];

  ngOnInit(): void {
    this.api.get<Center>('').subscribe(c => {
      c.opening_hours = [...c.opening_hours].sort((a, b) => a.day - b.day);
      this.c.set(c);
    });
  }

  locate(c: Center): void {
    navigator.geolocation?.getCurrentPosition(p => { c.lat = p.coords.latitude; c.lng = p.coords.longitude; this.c.set({ ...c }); });
  }

  upload(ev: Event, key: 'logo_url' | 'cover_url'): void {
    const file = (ev.target as HTMLInputElement).files?.[0];
    if (file) this.root.upload(file).subscribe(r => this.c.update(c => c && { ...c, [key]: r.url }));
  }

  setReminders(c: Center, value: string): void {
    c.points_expiry_reminders = value.split(/[,;\s]+/).map(v => parseInt(v, 10)).filter(v => v > 0);
  }

  save(): void {
    const { id, slug, is_active, current_queue, ...body } = this.c()! as Center & Record<string, unknown>;
    delete (body as Record<string, unknown>)['created_at'];
    if (!body.email) body.email = null;
    this.api.patch<Center>('', body).subscribe(c => { this.c.set(c); this.store.center.set(c); this.toast.success('Paramètres enregistrés'); });
  }
}
