import { DatePipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/auth.service';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { Member, MemberRole, Washer } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { ConfirmService } from '../../shared/confirm.service';
import { ModalComponent } from '../../shared/modal.component';

@Component({
  selector: 'app-team',
  standalone: true,
  imports: [FormsModule, ModalComponent, DatePipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Équipe & laveurs</h1><p class="muted">Plusieurs gestionnaires peuvent valider les lavages. Chaque laveur est suivi individuellement.</p></div>
      </div>
      <div class="grid grid-2">
        <div class="card">
          <div class="card-head">
            <div><h2>Gestionnaires</h2><p class="small muted">Accès au back-office et validation des lavages</p></div>
            @if (auth.isOwner()) { <button class="btn primary sm" (click)="newMember()"><span class="icon">person_add</span>Inviter</button> }
          </div>
          @for (m of members(); track m.id) {
            <div class="list-item" [class.off]="!m.is_active">
              <span class="avatar">{{ m.first_name[0] }}{{ m.last_name[0] || '' }}</span>
              <div style="flex:1; min-width:0"><strong>{{ m.first_name }} {{ m.last_name }}</strong><div class="small muted">{{ m.email }}</div></div>
              <span class="badge" [class.warning]="m.role === 'owner'">{{ m.role === 'owner' ? 'Propriétaire' : 'Gestionnaire' }}</span>
              @if (auth.isOwner() && m.user_id !== auth.user()?.id) {
                <label class="switch" title="Accès actif"><input type="checkbox" [checked]="m.is_active" (change)="toggleMember(m)"><span class="track"></span></label>
                <button class="btn ghost icon-only sm" (click)="removeMember(m)"><span class="icon">person_remove</span></button>
              }
            </div>
          }
        </div>
        <div class="card">
          <div class="card-head">
            <div><h2>Laveurs</h2><p class="small muted">Pour savoir qui a lavé chaque véhicule</p></div>
            <button class="btn primary sm" (click)="editWasher()"><span class="icon">add</span>Ajouter</button>
          </div>
          @for (w of store.washers(); track w.id) {
            <div class="list-item" [class.off]="!w.is_active">
              @if (w.photo_url) { <img class="avatar" [src]="w.photo_url" alt=""> } @else { <span class="avatar alt">{{ w.first_name[0] }}</span> }
              <div style="flex:1"><strong>{{ w.full_name }}</strong><div class="small muted">{{ w.phone || 'Pas de téléphone' }} @if (w.commission_rate) { · commission {{ w.commission_rate }} % }</div></div>
              @if (!w.is_active) { <span class="badge neutral">Inactif</span> }
              <button class="btn ghost icon-only sm" (click)="editWasher(w)"><span class="icon">edit</span></button>
              <button class="btn ghost icon-only sm" (click)="removeWasher(w)"><span class="icon">delete</span></button>
            </div>
          } @empty { <div class="empty"><span class="icon">engineering</span>Aucun laveur enregistré</div> }
        </div>
      </div>
    </div>

    <app-modal [open]="!!member()" title="Ajouter un gestionnaire" subtitle="S'il n'a pas encore de compte, il sera créé avec le mot de passe indiqué." (close)="member.set(null)">
      @if (member(); as m) {
        <div class="form-grid">
          <div class="field"><label>Prénom *</label><input class="input" [(ngModel)]="m.first_name"></div>
          <div class="field"><label>Nom</label><input class="input" [(ngModel)]="m.last_name"></div>
          <div class="field full"><label>E-mail *</label><input class="input" type="email" [(ngModel)]="m.email"></div>
          <div class="field"><label>Téléphone</label><input class="input" [(ngModel)]="m.phone"></div>
          <div class="field"><label>Mot de passe provisoire</label><input class="input" type="text" [(ngModel)]="m.password" placeholder="6 caractères min."></div>
          <div class="field full"><label>Rôle</label>
            <div class="chips">
              <button type="button" class="chip" [class.active]="m.role === 'manager'" (click)="m.role = 'manager'">Gestionnaire</button>
              <button type="button" class="chip" [class.active]="m.role === 'owner'" (click)="m.role = 'owner'">Co-propriétaire</button>
            </div>
          </div>
        </div>
      }
      <div modal-actions><button class="btn" (click)="member.set(null)">Annuler</button><button class="btn primary" [disabled]="!member()?.email || !member()?.first_name" (click)="saveMember()">Ajouter</button></div>
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
  styles: [`.off { opacity: .5; } .avatar.alt { background: var(--grad-eco); } img.avatar { object-fit: cover; }`],
})
export class TeamComponent implements OnInit {
  private api = inject(CenterApi);
  private toast = inject(ToastService);
  private confirm = inject(ConfirmService);
  auth = inject(AuthService);
  store = inject(CenterStore);
  members = signal<Member[]>([]);
  member = signal<{ email: string; first_name: string; last_name: string; phone: string; password: string; role: MemberRole } | null>(null);
  washer = signal<Partial<Washer> | null>(null);

  ngOnInit(): void { this.loadMembers(); }
  loadMembers(): void { this.api.get<Member[]>('/members').subscribe(m => this.members.set(m)); }

  newMember(): void { this.member.set({ email: '', first_name: '', last_name: '', phone: '', password: '', role: 'manager' }); }
  saveMember(): void {
    const m = this.member()!;
    this.api.post('/members', { ...m, password: m.password || null, phone: m.phone || null })
      .subscribe(() => { this.toast.success('Gestionnaire ajouté'); this.member.set(null); this.loadMembers(); });
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
