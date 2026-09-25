import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/auth.service';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { Member, MemberRole, Permission, PermissionDef, Washer } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { ConfirmService } from '../../shared/confirm.service';
import { ModalComponent } from '../../shared/modal.component';

interface MemberForm {
  id?: number; email: string; first_name: string; last_name: string; phone: string; password: string;
  role: MemberRole; permissions: Permission[];
}

@Component({
  selector: 'app-team',
  standalone: true,
  imports: [FormsModule, ModalComponent],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Équipe & laveurs</h1><p class="muted">Chaque gestionnaire a ses propres droits. Chaque laveur est suivi individuellement.</p></div>
      </div>
      <div class="grid grid-2">
        <div class="card">
          <div class="card-head">
            <div><h2>Gestionnaires</h2><p class="small muted">Tous peuvent valider les lavages, scanner les clients, gérer la file et les réservations</p></div>
            @if (auth.can('manage_team')) { <button class="btn primary sm" (click)="newMember()"><span class="icon">person_add</span>Ajouter</button> }
          </div>
          @for (m of members(); track m.id) {
            <div class="member" [class.off]="!m.is_active">
              <div class="list-item">
                <span class="avatar">{{ m.first_name[0] }}{{ m.last_name[0] || '' }}</span>
                <div style="flex:1; min-width:0"><strong>{{ m.first_name }} {{ m.last_name }}</strong><div class="small muted">{{ m.email }}</div></div>
                <span class="badge" [class.warning]="m.role === 'owner'">{{ m.role === 'owner' ? 'Propriétaire' : 'Gestionnaire' }}</span>
                @if (canEdit(m)) {
                  <button class="btn ghost icon-only sm" title="Modifier les droits" (click)="editMember(m)"><span class="icon">tune</span></button>
                  <label class="switch" title="Accès actif"><input type="checkbox" [checked]="m.is_active" (change)="toggleMember(m)"><span class="track"></span></label>
                  <button class="btn ghost icon-only sm" title="Retirer" (click)="removeMember(m)"><span class="icon">person_remove</span></button>
                }
              </div>
              @if (m.role !== 'owner') {
                <div class="perms">
                  @for (p of catalog(); track p.key) {
                    <span class="perm" [class.on]="m.permissions.includes(p.key)"><span class="icon">{{ m.permissions.includes(p.key) ? 'check' : 'block' }}</span>{{ p.label }}</span>
                  }
                </div>
              } @else { <div class="perms"><span class="perm on"><span class="icon">verified</span>Tous les droits</span></div> }
            </div>
          }
        </div>
        <div class="card">
          <div class="card-head">
            <div><h2>Laveurs</h2><p class="small muted">Pour savoir qui a lavé chaque véhicule</p></div>
            @if (auth.can('manage_washers')) { <button class="btn primary sm" (click)="editWasher()"><span class="icon">add</span>Ajouter</button> }
          </div>
          @for (w of store.washers(); track w.id) {
            <div class="list-item" [class.off]="!w.is_active">
              @if (w.photo_url) { <img class="avatar" [src]="w.photo_url" alt=""> } @else { <span class="avatar alt">{{ w.first_name[0] }}</span> }
              <div style="flex:1"><strong>{{ w.full_name }}</strong><div class="small muted">{{ w.phone || 'Pas de téléphone' }} @if (w.commission_rate) { · commission {{ w.commission_rate }} % }</div></div>
              @if (!w.is_active) { <span class="badge neutral">Inactif</span> }
              @if (auth.can('manage_washers')) {
                <button class="btn ghost icon-only sm" (click)="editWasher(w)"><span class="icon">edit</span></button>
                <button class="btn ghost icon-only sm" (click)="removeWasher(w)"><span class="icon">delete</span></button>
              }
            </div>
          } @empty { <div class="empty"><span class="icon">engineering</span>Aucun laveur enregistré</div> }
        </div>
      </div>
    </div>

    <app-modal [open]="!!member()" [title]="member()?.id ? 'Droits du gestionnaire' : 'Ajouter un gestionnaire'"
      [subtitle]="member()?.id ? '' : 'S\\'il n\\'a pas encore de compte, il sera créé avec le mot de passe indiqué.'" [width]="620" (close)="member.set(null)">
      @if (member(); as m) {
        <div class="form-grid">
          @if (!m.id) {
            <div class="field"><label>Prénom *</label><input class="input" [(ngModel)]="m.first_name"></div>
            <div class="field"><label>Nom</label><input class="input" [(ngModel)]="m.last_name"></div>
            <div class="field full"><label>E-mail *</label><input class="input" type="email" [(ngModel)]="m.email"></div>
            <div class="field"><label>Téléphone</label><input class="input" [(ngModel)]="m.phone"></div>
            <div class="field"><label>Mot de passe provisoire</label><input class="input" type="text" [(ngModel)]="m.password" placeholder="6 caractères min."></div>
          } @else {
            <p class="full"><strong>{{ m.first_name }} {{ m.last_name }}</strong> · <span class="muted">{{ m.email }}</span></p>
          }
          @if (auth.isOwner()) {
            <div class="field full"><label>Rôle</label>
              <div class="chips">
                <button type="button" class="chip" [class.active]="m.role === 'manager'" (click)="m.role = 'manager'">Gestionnaire</button>
                <button type="button" class="chip" [class.active]="m.role === 'owner'" (click)="m.role = 'owner'">Co-propriétaire (tous les droits)</button>
              </div>
            </div>
          }
          @if (m.role === 'manager') {
            <div class="field full">
              <label>Droits</label>
              <div class="perm-list">
                @for (p of catalog(); track p.key) {
                  <label class="perm-row" [class.locked]="!auth.can(p.key)">
                    <label class="switch"><input type="checkbox" [checked]="m.permissions.includes(p.key)" [disabled]="!auth.can(p.key)" (change)="togglePerm(m, p.key)"><span class="track"></span></label>
                    <span><strong>{{ p.label }}</strong><small>{{ p.description }}</small>
                      @if (!auth.can(p.key)) { <small class="lock"><span class="icon">lock</span>Vous ne possédez pas ce droit</small> }</span>
                  </label>
                }
              </div>
            </div>
          }
        </div>
      }
      <div modal-actions>
        <button class="btn" (click)="member.set(null)">Annuler</button>
        <button class="btn primary" [disabled]="!member()?.id && (!member()?.email || !member()?.first_name)" (click)="saveMember()">{{ member()?.id ? 'Enregistrer' : 'Ajouter' }}</button>
      </div>
    </app-modal>

    <app-modal [open]="!!washer()" [title]="washer()?.id ? 'Modifier le laveur' : 'Nouveau laveur'" (close)="washer.set(null)">
      @if (washer(); as w) {
        <div class="form-grid">
          <div class="field"><label>Prénom *</label><input class="input" [(ngModel)]="w.first_name"></div>
          <div class="field"><label>Nom</label><input class="input" [(ngModel)]="w.last_name"></div>
          <div class="field"><label>Téléphone</label><input class="input" [(ngModel)]="w.phone"></div>
          <div class="field"><label>Commission (%)</label><input class="input" type="number" min="0" max="100" [(ngModel)]="w.commission_rate"></div>
          <label class="switch full"><input type="checkbox" [(ngModel)]="w.is_active"><span class="track"></span>Actif</label>
        </div>
      }
      <div modal-actions><button class="btn" (click)="washer.set(null)">Annuler</button><button class="btn primary" [disabled]="!washer()?.first_name" (click)="saveWasher()">Enregistrer</button></div>
    </app-modal>
  `,
  styles: [`
    .off { opacity: .5; } .avatar.alt { background: var(--grad-eco); } img.avatar { object-fit: cover; }
    .member { border-bottom: 1px dashed var(--border); padding-bottom: 10px; &:last-child { border-bottom: none; } .list-item { border-bottom: none; padding-bottom: 6px; } }
    .perms { display: flex; flex-wrap: wrap; gap: 6px; padding-left: 50px; }
    .perm { display: inline-flex; align-items: center; gap: 3px; font-size: 11px; font-weight: 600; padding: 3px 8px; border-radius: 99px; background: var(--surface-2); color: var(--muted); border: 1px solid var(--border); text-decoration: line-through;
      .icon { font-size: 13px; }
      &.on { background: var(--primary-soft); color: var(--primary); border-color: transparent; text-decoration: none; }
    }
    .perm-list { display: grid; gap: 4px; }
    .perm-row { display: flex; gap: 12px; align-items: flex-start; padding: 10px 12px; border-radius: 12px; cursor: pointer;
      &:hover { background: var(--surface-2); }
      &.locked { opacity: .6; cursor: not-allowed; }
      > span { display: flex; flex-direction: column; strong { font-size: 14px; } small { color: var(--text-2); font-size: 12px; } }
      .lock { display: flex; align-items: center; gap: 3px; color: var(--warning) !important; .icon { font-size: 14px; } }
    }
  `],
})
export class TeamComponent implements OnInit {
  private api = inject(CenterApi);
  private toast = inject(ToastService);
  private confirm = inject(ConfirmService);
  auth = inject(AuthService);
  store = inject(CenterStore);
  members = signal<Member[]>([]);
  catalog = signal<PermissionDef[]>([]);
  member = signal<MemberForm | null>(null);
  washer = signal<Partial<Washer> | null>(null);

  ngOnInit(): void {
    this.loadMembers();
    this.api.get<{ permissions: PermissionDef[] }>('/permissions').subscribe(r => this.catalog.set(r.permissions));
  }
  loadMembers(): void { this.api.get<Member[]>('/members').subscribe(m => this.members.set(m)); }

  /** Un membre peut être modifié par quelqu'un qui gère l'équipe, sauf soi-même et (pour un non-propriétaire) les propriétaires. */
  canEdit(m: Member): boolean {
    return this.auth.can('manage_team') && m.user_id !== this.auth.user()?.id && (this.auth.isOwner() || m.role !== 'owner');
  }

  newMember(): void {
    // Par défaut : les droits usuels que l'on possède soi-même (hors équipe et annulation)
    const usual: Permission[] = ['manage_washers', 'manage_catalog', 'manage_rewards', 'view_reports', 'adjust_points', 'manage_settings'];
    this.member.set({ email: '', first_name: '', last_name: '', phone: '', password: '', role: 'manager',
      permissions: usual.filter(p => this.auth.can(p)) });
  }
  editMember(m: Member): void {
    this.member.set({ id: m.id, email: m.email, first_name: m.first_name, last_name: m.last_name, phone: m.phone ?? '',
      password: '', role: m.role, permissions: [...m.permissions] });
  }
  togglePerm(m: MemberForm, p: Permission): void {
    m.permissions = m.permissions.includes(p) ? m.permissions.filter(x => x !== p) : [...m.permissions, p];
    this.member.set({ ...m });
  }

  saveMember(): void {
    const m = this.member()!;
    const permissions = m.role === 'owner' ? [] : m.permissions;
    const req = m.id
      ? this.api.patch(`/members/${m.id}`, this.auth.isOwner() ? { role: m.role, permissions } : { permissions })
      : this.api.post('/members', { email: m.email, first_name: m.first_name, last_name: m.last_name, phone: m.phone || null,
          password: m.password || null, role: m.role, permissions });
    req.subscribe(() => { this.toast.success(m.id ? 'Droits mis à jour' : 'Gestionnaire ajouté'); this.member.set(null); this.loadMembers(); });
  }
  toggleMember(m: Member): void { this.api.patch(`/members/${m.id}`, { is_active: !m.is_active }).subscribe(() => this.loadMembers()); }
  async removeMember(m: Member): Promise<void> {
    if (!await this.confirm.ask('Retirer ce gestionnaire ?', `${m.first_name} n'aura plus accès au centre.`, { danger: true, confirmLabel: 'Retirer' })) return;
    this.api.delete(`/members/${m.id}`).subscribe(() => this.loadMembers());
  }

  editWasher(w?: Washer): void { this.washer.set(w ? { ...w } : { first_name: '', last_name: '', phone: '', commission_rate: 0, is_active: true }); }
  saveWasher(): void {
    const { id, full_name, created_at, ...body } = this.washer()!;
    const req = id ? this.api.patch(`/washers/${id}`, body) : this.api.post('/washers', body);
    req.subscribe(() => { this.toast.success('Laveur enregistré'); this.washer.set(null); this.store.refreshCatalog(); });
  }
  async removeWasher(w: Washer): Promise<void> {
    if (!await this.confirm.ask('Supprimer ce laveur ?', "S'il a déjà effectué des lavages, il sera désactivé pour conserver l'historique.", { danger: true, confirmLabel: 'Supprimer' })) return;
    this.api.delete(`/washers/${w.id}`).subscribe(() => this.store.refreshCatalog());
  }
}
