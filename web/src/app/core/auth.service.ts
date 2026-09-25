import { Injectable, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';
import { Me, Permission, TokenResponse } from './models';

const TOKEN_KEY = 'lavpro.token';
const CENTER_KEY = 'lavpro.center';

function read(key: string): string | null {
  try { return localStorage.getItem(key); } catch { return null; }
}
function write(key: string, value: string | null): void {
  try { value === null ? localStorage.removeItem(key) : localStorage.setItem(key, value); } catch { /* stockage indisponible */ }
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private api = inject(ApiService);
  private router = inject(Router);

  readonly token = signal<string | null>(read(TOKEN_KEY));
  readonly user = signal<Me | null>(null);
  private readonly selectedCenter = signal<number | null>(Number(read(CENTER_KEY)) || null);

  readonly isSuperadmin = computed(() => this.user()?.role === 'superadmin');
  readonly memberships = computed(() => this.user()?.memberships ?? []);
  readonly centerId = computed(() => {
    const list = this.memberships();
    const sel = this.selectedCenter();
    if (sel && (list.some(m => m.center_id === sel) || this.isSuperadmin())) return sel;
    return list[0]?.center_id ?? null;
  });
  readonly membership = computed(() => this.memberships().find(m => m.center_id === this.centerId()) ?? null);
  readonly isOwner = computed(() => this.isSuperadmin() || this.membership()?.role === 'owner');

  /** Le gestionnaire a-t-il ce droit dans le centre courant ? (propriétaire et super-admin : tous) */
  can(permission: Permission): boolean {
    return this.isOwner() || (this.membership()?.permissions ?? []).includes(permission);
  }

  login(email: string, password: string): Observable<TokenResponse> {
    return this.api.post<TokenResponse>('/auth/login', { email, password }).pipe(tap(r => this.setSession(r)));
  }

  registerCenter(body: unknown): Observable<TokenResponse> {
    return this.api.post<TokenResponse>('/auth/register-center', body).pipe(tap(r => this.setSession(r)));
  }

  loadMe(): Observable<Me> {
    return this.api.get<Me>('/auth/me').pipe(tap(u => this.user.set(u)));
  }

  selectCenter(id: number): void {
    this.selectedCenter.set(id);
    write(CENTER_KEY, String(id));
  }

  logout(): void {
    this.token.set(null);
    this.user.set(null);
    write(TOKEN_KEY, null);
    this.router.navigate(['/login']);
  }

  private setSession(r: TokenResponse): void {
    this.token.set(r.access_token);
    this.user.set(r.user);
    write(TOKEN_KEY, r.access_token);
  }
}
