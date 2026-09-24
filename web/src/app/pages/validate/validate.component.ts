import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, ElementRef, OnDestroy, OnInit, ViewChild, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Html5Qrcode } from 'html5-qrcode';
import { CenterApi } from '../../core/center-api.service';
import { CenterStore } from '../../core/center-store.service';
import { ClientLookup, PricingRule, Redemption, Wash } from '../../core/models';
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
      washer_id: this.washerId, booking_id: this.bookingId, plate: this.plate || null, note: this.note || null,
    }).subscribe({
      next: w => {
        this.saving.set(false);
        this.done.set(w);
        this.newBalance.set(c ? c.balance + w.points_earned : null);
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

  reset(): void {
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
