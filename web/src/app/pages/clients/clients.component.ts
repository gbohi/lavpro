import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Subject, debounceTime } from 'rxjs';
import { CenterApi } from '../../core/center-api.service';
import { ClientSummary, Transaction } from '../../core/models';
import { ToastService } from '../../core/toast.service';
import { ModalComponent } from '../../shared/modal.component';

const TX_LABEL: Record<string, string> = {
  earn: 'Lavage', redeem: 'Récompense', referral: 'Parrainage', welcome: 'Bienvenue', bonus: 'Bonus', adjust: 'Ajustement', refund: 'Remboursement',
};

@Component({
  selector: 'app-clients',
  standalone: true,
  imports: [FormsModule, DatePipe, DecimalPipe, ModalComponent],
  template: `
    <div class="page">
      <div class="page-head">
        <div><h1>Clients</h1><p class="muted">Votre base de clients fidélisés et leurs soldes de points.</p></div>
      </div>
      <div class="row" style="margin-bottom:20px">
        <div class="input-icon" style="flex:1; min-width:240px"><span class="icon">search</span>
          <input class="input" placeholder="Nom, e-mail, téléphone ou code membre" [(ngModel)]="q" (ngModelChange)="search$.next()">
        </div>
        <div class="chips">
          @for (s of segments; track s.value) {
            <button class="chip" [class.active]="segment === s.value" (click)="segment = s.value; load()"><span class="icon">{{ s.icon }}</span>{{ s.label }}</button>
          }
        </div>
      </div>
      <div class="card flush">
        <div class="table-wrap">
          <table class="table">
            <thead><tr><th>Client</th><th>Contact</th><th class="num">Visites</th><th class="num">Solde</th><th class="num">Cumul gagné</th><th>Dernière visite</th><th></th></tr></thead>
            <tbody>
              @for (c of clients(); track c.user_id) {
                <tr>
                  <td><div class="row" style="flex-wrap:nowrap"><span class="avatar">{{ c.first_name[0] }}{{ c.last_name[0] || '' }}</span>
                    <div><strong>{{ c.first_name }} {{ c.last_name }}</strong> @if (c.is_loyal) { <span class="icon filled" style="color:#f59e0b;font-size:16px" title="Client fidèle">workspace_premium</span> }
                    <div class="small muted">{{ c.member_code }}</div></div></div></td>
                  <td class="small">{{ c.email }}<div class="muted">{{ c.phone }}</div></td>
                  <td class="num">{{ c.visits }}</td>
                  <td class="num"><strong>{{ c.balance | number }}</strong> pts</td>
                  <td class="num">{{ c.total_earned | number }}</td>
                  <td>{{ c.last_visit_at ? (c.last_visit_at | date:'dd/MM/yyyy') : '—' }}</td>
                  <td class="num"><button class="btn sm" (click)="open(c)">Détails</button></td>
                </tr>
              } @empty {
                <tr><td colspan="7"><div class="empty"><span class="icon">groups</span>Aucun client trouvé</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <app-modal [open]="!!selected()" [title]="(selected()?.first_name ?? '') + ' ' + (selected()?.last_name ?? '')"
      [subtitle]="'Solde actuel : ' + (selected()?.balance ?? 0) + ' points'" [width]="620" (close)="selected.set(null)">
      <div class="card adjust">
        <h3>Ajuster les points</h3>
        <div class="row" style="margin-top:10px">
          <input class="input" type="number" [(ngModel)]="adjust.points" placeholder="+50 ou -20" style="width:140px">
          <input class="input" [(ngModel)]="adjust.note" placeholder="Motif (obligatoire)" style="flex:1; min-width:160px">
          <button class="btn primary" [disabled]="!adjust.points || adjust.note.length < 2" (click)="doAdjust()">Appliquer</button>
        </div>
      </div>
      <h3 style="margin:18px 0 8px">Historique des points</h3>
      @for (t of transactions(); track t.id) {
        <div class="list-item">
          <span class="badge" [class.success]="t.points > 0" [class.danger]="t.points < 0">{{ t.points > 0 ? '+' : '' }}{{ t.points }}</span>
          <div style="flex:1"><strong>{{ txLabel[t.type] || t.type }}</strong><div class="small muted">{{ t.note }}</div></div>
          <span class="small muted">{{ t.created_at | date:'dd/MM/yy HH:mm' }}</span>
        </div>
      } @empty { <p class="muted">Aucune transaction</p> }
    </app-modal>
  `,
  styles: [`.adjust { background: var(--surface-2); box-shadow: none; }`],
})
export class ClientsComponent implements OnInit {
  private api = inject(CenterApi);
  private toast = inject(ToastService);
  txLabel = TX_LABEL;
  clients = signal<ClientSummary[]>([]);
  selected = signal<ClientSummary | null>(null);
  transactions = signal<Transaction[]>([]);
  q = '';
  segment: string | null = null;
  search$ = new Subject<void>();
  adjust = { points: 0, note: '' };
  segments = [
    { value: null, label: 'Tous', icon: 'group' },
    { value: 'loyal', label: 'Fidèles', icon: 'workspace_premium' },
    { value: 'new', label: 'Nouveaux', icon: 'fiber_new' },
    { value: 'inactive', label: 'Inactifs', icon: 'bedtime' },
  ];

  ngOnInit(): void {
    this.search$.pipe(debounceTime(300)).subscribe(() => this.load());
    this.load();
  }

  load(): void {
    this.api.get<ClientSummary[]>('/clients', { q: this.q, segment: this.segment }).subscribe(c => this.clients.set(c));
  }

  open(c: ClientSummary): void {
    this.selected.set(c);
    this.adjust = { points: 0, note: '' };
    this.api.get<Transaction[]>(`/clients/${c.user_id}/transactions`).subscribe(t => this.transactions.set(t));
  }

  doAdjust(): void {
    const c = this.selected();
    if (!c) return;
    this.api.post('/points/adjust', { user_id: c.user_id, points: this.adjust.points, note: this.adjust.note }).subscribe(() => {
      this.toast.success('Points mis à jour');
      this.selected.set({ ...c, balance: c.balance + this.adjust.points });
      this.open(this.selected()!);
      this.load();
    });
  }
}
