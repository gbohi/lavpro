import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, ElementRef, OnDestroy, OnInit, ViewChild, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Html5Qrcode } from 'html5-qrcode';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { ClientLookup, PaymentMethod, PricingRule, Redemption, Wash } from '../../core/models';
import { ToastService } from '../../core/toast.service';

@Component({
  selector: 'app-validate',
  standalone: true,
  imports: [FormsModule, DecimalPipe, DatePipe],
  templateUrl: './validate.component.html',
  styleUrl: './validate.component.scss',
})
export class ValidateComponent implements OnInit, OnDestroy {
  private api = inject(CenterApi);
  store = inject(CenterStore);
  private toast = inject(ToastService);
  @ViewChild('codeInput') codeInput?: ElementRef<HTMLInputElement>;

  code = '';
  client = signal<ClientLookup | null>(null);
  walkIn = signal(false);
  pricing = signal<PricingRule[]>([]);
  scanning = signal(false);
  saving = signal(false);
  done = signal<Wash | null>(null);
  newBalance = signal<number | null>(null);
  payment = signal<PaymentMethod>('standard');
  redemptionId = signal<number | null>(null);
  redemptionCode = '';

  vehicleTypeId = signal<number | null>(null);
  serviceId = signal<number | null>(null);
  washerId: number | null = null;
  plate = '';
  note = '';
  bookingId: number | null = null;
  private scanner?: Html5Qrcode;

  activeServices = computed(() => this.store.services().filter(s => s.is_active));
  activeVehicles = computed(() => this.store.vehicleTypes().filter(v => v.is_active));
  activeWashers = computed(() => this.store.washers().filter(w => w.is_active));
  selectedRule = computed(() => this.rule(this.serviceId(), this.vehicleTypeId()));
  washRewards = computed(() => this.client()?.pending_redemptions.filter(r => r.is_wash) ?? []);
  selectedRedemption = computed(() => this.washRewards().find(r => r.id === this.redemptionId()) ?? null);

  /** Incohérence entre la récompense choisie et le service / véhicule sélectionnés. */
  rewardIssue = computed(() => {
    const r = this.selectedRedemption();
    if (this.payment() !== 'reward' || !r) return null;
    if (this.serviceId() && r.service_type_id !== this.serviceId()) return `Cette récompense offre le service « ${r.service_name} ».`;
    if (this.vehicleTypeId() && r.vehicle_type_id && r.vehicle_type_id !== this.vehicleTypeId()) return `Cette récompense est valable pour : ${r.vehicle_type_name}.`;
    return null;
  });

  /** Raison pour laquelle le paiement en points est impossible (null si possible). */
  pointsIssue = computed(() => {
    const c = this.client();
    const r = this.selectedRule();
    if (!c) return 'client non identifié';
    if (!r) return 'choisissez un véhicule et un service';
    if (!r.points_price) return 'ce lavage n\'a pas de prix en points';
    if (c.balance < r.points_price) return `solde insuffisant (${r.points_price} pts requis, ${c.balance} disponibles)`;
    return null;
  });

  ready = computed(() => (this.client() || this.walkIn()) && this.serviceId() && this.vehicleTypeId());

  ngOnInit(): void {
    this.api.get<PricingRule[]>('/pricing').subscribe(p => this.pricing.set(p));
    setTimeout(() => this.codeInput?.nativeElement.focus(), 100);
  }
  ngOnDestroy(): void { this.stopScan(); }

  rule(serviceId: number | null, vehicleId: number | null): PricingRule | undefined {
    return this.pricing().find(r => r.service_type_id === serviceId && r.vehicle_type_id === vehicleId && r.is_active);
  }

  async startScan(): Promise<void> {
    this.scanning.set(true);
    await new Promise(r => setTimeout(r, 50));
    this.scanner = new Html5Qrcode('qr-reader');
    try {
      await this.scanner.start({ facingMode: 'environment' }, { fps: 10, qrbox: { width: 240, height: 240 } },
        text => { this.code = text; this.stopScan(); this.lookup(); }, () => undefined);
    } catch {
      this.toast.error("Impossible d'accéder à la caméra");
      this.scanning.set(false);
    }
  }

  stopScan(): void {
    if (this.scanner?.isScanning) this.scanner.stop().catch(() => undefined);
    this.scanning.set(false);
  }

  lookup(): void {
    const code = this.code.trim();
    if (!code) return;
    this.api.get<ClientLookup>('/clients/lookup', { code }).subscribe(c => {
      this.client.set(c);
      this.walkIn.set(false);
      this.done.set(null);
      const b = c.upcoming_bookings[0];
      if (b) {
        this.bookingId = b.id;
        this.serviceId.set(b.service_type_id);
        this.vehicleTypeId.set(b.vehicle_type_id);
      }
      if (c.vehicles.length === 1 && c.vehicles[0].plate) this.plate = c.vehicles[0].plate;
    });
  }

  startWalkIn(): void {
    this.reset();
    this.walkIn.set(true);
  }

  validate(): void {
    if (!this.ready()) return;
    this.saving.set(true);
    const c = this.client();
    this.api.post<Wash>('/washes', {
      client_code: c?.member_code ?? null, service_type_id: this.serviceId(), vehicle_type_id: this.vehicleTypeId(),
      washer_id: this.washerId, booking_id: this.bookingId, payment_method: this.payment(),
      redemption_id: this.payment() === 'reward' ? this.redemptionId() : null, plate: this.plate || null, note: this.note || null,
    }).subscribe({
      next: w => {
        this.saving.set(false);
        this.done.set(w);
        this.newBalance.set(c ? c.balance + w.points_earned - w.points_spent : null);
        this.toast.success('Lavage validé');
      },
      error: () => this.saving.set(false),
    });
  }

  giveReward(r: Redemption): void {
    this.api.post<Redemption>(`/redemptions/${r.id}/validate`).subscribe(() => {
      this.toast.success(`« ${r.reward_name} » remis au client`);
      this.client.update(c => c && { ...c, pending_redemptions: c.pending_redemptions.filter(x => x.id !== r.id) });
    });
  }

  validateRedemptionCode(): void {
    const code = this.redemptionCode.trim();
    if (!code) return;
    this.api.post<Redemption>(`/redemptions/${encodeURIComponent(code)}/validate`).subscribe(r => {
      this.toast.success(`« ${r.reward_name} » remis à ${r.client_name}`);
      this.redemptionCode = '';
    });
  }

  setPayment(p: PaymentMethod): void {
    this.payment.set(p);
    if (p !== 'reward') this.redemptionId.set(null);
  }

  /** Utilise une récompense « lavage offert » : préremplit le service et le véhicule. */
  useReward(r: Redemption): void {
    this.payment.set('reward');
    this.redemptionId.set(r.id);
    if (r.service_type_id) this.serviceId.set(r.service_type_id);
    if (r.vehicle_type_id) this.vehicleTypeId.set(r.vehicle_type_id);
  }

  reset(): void {
    this.payment.set('standard');
    this.redemptionId.set(null);
    this.client.set(null);
    this.walkIn.set(false);
    this.done.set(null);
    this.code = '';
    this.plate = '';
    this.note = '';
    this.bookingId = null;
    this.serviceId.set(null);
    this.vehicleTypeId.set(null);
    setTimeout(() => this.codeInput?.nativeElement.focus(), 50);
  }
}
