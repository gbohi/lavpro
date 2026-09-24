import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth.service';
import { ToastService } from '../../core/toast.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, RouterLink],
  template: `
    <section class="hero">
      <div class="bubble b1"></div><div class="bubble b2"></div>
      <div class="brand"><span class="logo"><span class="icon filled">water_drop</span></span> Lavpro</div>
      <div>
        <h1>Fidélisez, analysez et optimisez votre centre de lavage.</h1>
        <p class="lead">Validez les lavages en un scan, récompensez vos clients et pilotez votre activité en temps réel.</p>
        <div class="features">
          <div class="feature"><span class="icon">qr_code_scanner</span><div><strong>Validation en 2 secondes</strong><small>Scannez le QR code du client, les points sont crédités.</small></div></div>
          <div class="feature"><span class="icon">tune</span><div><strong>100 % paramétrable</strong><small>Services, véhicules, points, récompenses : c'est vous qui décidez.</small></div></div>
          <div class="feature"><span class="icon">insights</span><div><strong>Statistiques en temps réel</strong><small>Lavages, services populaires, fidélité, performance des laveurs.</small></div></div>
        </div>
      </div>
      <div class="foot">© Lavpro · Roulez propre</div>
    </section>
    <section class="panel">
      <div class="form-card">
        <h2>Bon retour 👋</h2>
        <p class="muted">Connectez-vous à votre espace gestionnaire.</p>
        @if (denied) {
          <p class="badge warning" style="margin-top:16px">Ce compte n'est rattaché à aucun centre.</p>
        }
        <form (ngSubmit)="submit()">
          <div class="field">
            <label for="email">E-mail</label>
            <div class="input-icon"><span class="icon">mail</span><input id="email" class="input" type="email" name="email" [(ngModel)]="email" required autocomplete="email"></div>
          </div>
          <div class="field">
            <label for="password">Mot de passe</label>
            <div class="input-icon"><span class="icon">lock</span><input id="password" class="input" [type]="show() ? 'text' : 'password'" name="password" [(ngModel)]="password" required autocomplete="current-password"></div>
          </div>
          <label class="switch small"><input type="checkbox" [checked]="show()" (change)="show.set(!show())"><span class="track"></span>Afficher le mot de passe</label>
          <button class="btn primary lg block" [disabled]="loading()">
            @if (loading()) { Connexion… } @else { Se connecter <span class="icon">arrow_forward</span> }
          </button>
        </form>
        <p class="switch-link">Nouveau centre de lavage ? <a routerLink="/register">Inscrire mon centre</a></p>
      </div>
    </section>
  `,
  styleUrl: './auth-layout.scss',
})
export class LoginComponent {
  private auth = inject(AuthService);
  private router = inject(Router);
  private toast = inject(ToastService);
  email = '';
  password = '';
  loading = signal(false);
  show = signal(false);
  denied = !!inject(ActivatedRoute).snapshot.queryParamMap.get('denied');

  submit(): void {
    this.loading.set(true);
    this.auth.login(this.email, this.password).subscribe({
      next: r => {
        if (!r.user.memberships.length && r.user.role !== 'superadmin') {
          this.toast.error("Ce compte n'a pas accès à l'espace pro. Utilisez l'application mobile Lavpro.");
          this.auth.logout();
          this.loading.set(false);
          return;
        }
        this.router.navigate([r.user.memberships.length ? '/dashboard' : '/admin']);
      },
      error: () => this.loading.set(false),
    });
  }
}
