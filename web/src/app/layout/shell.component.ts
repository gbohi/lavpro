import { Component, OnDestroy, OnInit, computed, effect, inject, signal } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs';
import { AuthService } from '../core/auth.service';
import { CenterApi } from '../core/center-api.service';
import { CenterStore } from '../core/center-store.service';
import { Occupancy } from '../core/models';

interface NavItem { path: string; label: string; icon: string; ownerOnly?: boolean; }
interface NavGroup { title: string; items: NavItem[]; }

@Component({
  selector: 'app-shell',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './shell.component.html',
  styleUrl: './shell.component.scss',
})
export class ShellComponent implements OnInit, OnDestroy {
  auth = inject(AuthService);
  store = inject(CenterStore);
  private api = inject(CenterApi);
  private router = inject(Router);

  menuOpen = signal(false);
  occupancy = signal<Occupancy | null>(null);
  theme = signal<'light' | 'dark' | 'auto'>(this.readTheme());
  private timer?: ReturnType<typeof setInterval>;

  readonly groups: NavGroup[] = [
    { title: 'Activité', items: [
      { path: '/dashboard', label: 'Tableau de bord', icon: 'space_dashboard' },
      { path: '/validate', label: 'Valider un lavage', icon: 'qr_code_scanner' },
      { path: '/washes', label: 'Lavages', icon: 'local_car_wash' },
      { path: '/bookings', label: 'Réservations', icon: 'event_available' },
      { path: '/clients', label: 'Clients', icon: 'groups' },
    ] },
    { title: 'Fidélité', items: [
      { path: '/rewards', label: 'Récompenses', icon: 'redeem' },
      { path: '/promotions', label: 'Promotions', icon: 'campaign' },
    ] },
    { title: 'Configuration', items: [
      { path: '/catalog', label: 'Services & véhicules', icon: 'category' },
      { path: '/pricing', label: 'Prix & points', icon: 'price_change' },
      { path: '/team', label: 'Équipe & laveurs', icon: 'badge' },
      { path: '/reports', label: 'Rapports', icon: 'insights' },
      { path: '/settings', label: 'Paramètres du centre', icon: 'tune' },
    ] },
  ];

  initials = computed(() => {
    const u = this.auth.user();
    return u ? (u.first_name[0] ?? '') + (u.last_name[0] ?? '') : '';
  });

  constructor() {
    effect(() => {
      if (this.auth.centerId()) {
        this.store.load();
        this.refreshOccupancy();
      }
    }, { allowSignalWrites: true });
    this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(() => this.menuOpen.set(false));
  }

  ngOnInit(): void {
    this.applyTheme(this.theme());
    this.timer = setInterval(() => this.refreshOccupancy(), 30000);
  }
  ngOnDestroy(): void { clearInterval(this.timer); }

  refreshOccupancy(): void {
    if (!this.auth.centerId()) return;
    this.api.get<Occupancy>('/occupancy').subscribe(o => this.occupancy.set(o));
  }

  queue(delta: number): void {
    this.api.post<Occupancy>('/queue', { delta }).subscribe(o => this.occupancy.set(o));
  }

  switchCenter(id: string): void {
    this.auth.selectCenter(Number(id));
    this.router.navigate(['/dashboard']);
  }

  cycleTheme(): void {
    const next = this.theme() === 'auto' ? 'dark' : this.theme() === 'dark' ? 'light' : 'auto';
    this.theme.set(next);
    this.applyTheme(next);
    try { localStorage.setItem('lavpro.theme', next); } catch { /* ignore */ }
  }

  occupancyLabel(level?: string): string {
    return { low: 'Fluide', moderate: 'Modérée', high: 'Forte', closed: 'Fermé' }[level ?? ''] ?? '—';
  }

  private readTheme(): 'light' | 'dark' | 'auto' {
    try { return (localStorage.getItem('lavpro.theme') as 'light' | 'dark' | 'auto') || 'auto'; } catch { return 'auto'; }
  }
  private applyTheme(t: string): void {
    if (t === 'auto') delete document.documentElement.dataset['theme'];
    else document.documentElement.dataset['theme'] = t;
  }
}
