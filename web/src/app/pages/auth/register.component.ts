import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth.service';
import { ToastService } from '../../core/toast.service';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [FormsModule, RouterLink],
  template: `
    <section class="hero">
      <div class="bubble b1"></div><div class="bubble b2"></div>
      <div class="brand"><span class="logo"><span class="icon filled">water_drop</span></span> Lavpro</div>
      <div>
        <h1>Inscrivez votre centre en 2 minutes.</h1>
        <p class="lead">Un seul enregistrement, plusieurs gestionnaires, des laveurs suivis individuellement. Même en votre absence, un collègue valide les lavages.</p>
        <div class="features">
          <div class="feature"><span class="icon">groups</span><div><strong>Travail en équipe</strong><small>Ajoutez gestionnaires et laveurs à tout moment.</small></div></div>
          <div class="feature"><span class="icon">redeem</span><div><strong>Récompenses sur mesure</strong><small>Lavages offerts, senteurs, tapis, bidons d'huile…</small></div></div>
        </div>
      </div>
      <div class="foot">© Lavpro · Roulez propre</div>
    </section>
    <section class="panel">
      <div class="form-card">
        <div class="steps">
          <span [class.on]="step() >= 1">1</span><i></i><span [class.on]="step() >= 2">2</span>
        </div>
        <h2>{{ step() === 1 ? 'Votre centre' : 'Votre compte gérant' }}</h2>
        <p class="muted">{{ step() === 1 ? 'Ces informations seront visibles par vos clients.' : 'Vous serez le propriétaire du centre.' }}</p>
        <form (ngSubmit)="next()">
          @if (step() === 1) {
            <div class="field"><label>Nom du centre *</label><input class="input" name="cn" [(ngModel)]="f.center_name" required minlength="2"></div>
            <div class="field"><label>Adresse</label><input class="input" name="ad" [(ngModel)]="f.address"></div>
            <div class="form-grid">
              <div class="field"><label>Ville</label><input class="input" name="ci" [(ngModel)]="f.city"></div>
              <div class="field"><label>Pays</label><input class="input" name="co" [(ngModel)]="f.country"></div>
              <div class="field"><label>Téléphone</label><input class="input" name="ph" [(ngModel)]="f.phone"></div>
              <div class="field"><label>Devise</label><input class="input" name="cu" [(ngModel)]="f.currency" maxlength="8"></div>
            </div>
            <button type="button" class="btn block" (click)="locate()"><span class="icon">my_location</span>
              {{ f.lat ? 'Position enregistrée (' + f.lat.toFixed(4) + ', ' + f.lng!.toFixed(4) + ')' : 'Utiliser ma position actuelle' }}</button>
            <button class="btn primary lg block" [disabled]="!f.center_name">Continuer <span class="icon">arrow_forward</span></button>
          } @else {
            <div class="form-grid">
              <div class="field"><label>Prénom *</label><input class="input" name="fn" [(ngModel)]="f.owner_first_name" required></div>
              <div class="field"><label>Nom</label><input class="input" name="ln" [(ngModel)]="f.owner_last_name"></div>
            </div>
            <div class="field"><label>E-mail *</label><input class="input" type="email" name="em" [(ngModel)]="f.owner_email" required></div>
            <div class="field"><label>Mot de passe * <span class="hint">(6 caractères min.)</span></label><input class="input" type="password" name="pw" [(ngModel)]="f.owner_password" required minlength="6"></div>
            <div class="row">
              <button type="button" class="btn lg" (click)="step.set(1)"><span class="icon">arrow_back</span></button>
              <button class="btn primary lg" style="flex:1" [disabled]="loading()">{{ loading() ? 'Création…' : 'Créer mon centre' }}</button>
            </div>
          }
        </form>
        <p class="switch-link">Déjà inscrit ? <a routerLink="/login">Se connecter</a></p>
      </div>
    </section>
  `,
  styleUrl: './auth-layout.scss',
  styles: [`
    .steps { display: flex; align-items: center; gap: 8px; margin-bottom: 20px;
      span { width: 30px; height: 30px; border-radius: 50%; display: grid; place-items: center; font-weight: 800; background: var(--surface); border: 1px solid var(--border); color: var(--muted); }
      span.on { background: var(--grad); color: #fff; border: none; }
      i { width: 40px; height: 2px; background: var(--border); }
    }
  `],
})
export class RegisterComponent {
  private auth = inject(AuthService);
  private router = inject(Router);
  private toast = inject(ToastService);
  step = signal(1);
  loading = signal(false);
  f = {
    center_name: '', address: '', city: '', country: '', phone: '', currency: 'XOF',
    lat: null as number | null, lng: null as number | null,
    owner_first_name: '', owner_last_name: '', owner_email: '', owner_password: '',
  };

  locate(): void {
    navigator.geolocation?.getCurrentPosition(
      p => { this.f.lat = p.coords.latitude; this.f.lng = p.coords.longitude; },
      () => this.toast.error('Position indisponible'),
    );
  }

  next(): void {
    if (this.step() === 1) { this.step.set(2); return; }
    this.loading.set(true);
    this.auth.registerCenter(this.f).subscribe({
      next: () => { this.toast.success('Bienvenue sur Lavpro ! Configurez vos prix et points.'); this.router.navigate(['/pricing']); },
      error: () => this.loading.set(false),
    });
  }
}
