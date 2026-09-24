import { Injectable, inject, signal } from '@angular/core';
import { forkJoin } from 'rxjs';
import { CenterApi } from './center-api.service';
import { Center, ServiceType, VehicleType, Washer } from './models';

/** Données de référence du centre courant, partagées entre les écrans. */
@Injectable({ providedIn: 'root' })
export class CenterStore {
  private api = inject(CenterApi);
  readonly center = signal<Center | null>(null);
  readonly services = signal<ServiceType[]>([]);
  readonly vehicleTypes = signal<VehicleType[]>([]);
  readonly washers = signal<Washer[]>([]);

  load(): void {
    forkJoin({
      center: this.api.get<Center>(''),
      services: this.api.get<ServiceType[]>('/services'),
      vehicles: this.api.get<VehicleType[]>('/vehicle-types'),
      washers: this.api.get<Washer[]>('/washers'),
    }).subscribe(r => {
      this.center.set(r.center);
      this.services.set(r.services);
      this.vehicleTypes.set(r.vehicles);
      this.washers.set(r.washers);
    });
  }

  refreshCatalog(): void {
    this.api.get<ServiceType[]>('/services').subscribe(s => this.services.set(s));
    this.api.get<VehicleType[]>('/vehicle-types').subscribe(v => this.vehicleTypes.set(v));
    this.api.get<Washer[]>('/washers').subscribe(w => this.washers.set(w));
  }

  get currency(): string { return this.center()?.currency ?? ''; }
}
