import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from './api.service';
import { AuthService } from './auth.service';

/** Raccourci vers les endpoints /manage/centers/{id} du centre sélectionné. */
@Injectable({ providedIn: 'root' })
export class CenterApi {
  private api = inject(ApiService);
  private auth = inject(AuthService);

  private p(path: string): string {
    return `/manage/centers/${this.auth.centerId()}${path}`;
  }
  get<T>(path: string, params?: Record<string, string | number | boolean | null | undefined>): Observable<T> {
    return this.api.get<T>(this.p(path), params);
  }
  post<T>(path: string, body: unknown = {}): Observable<T> { return this.api.post<T>(this.p(path), body); }
  put<T>(path: string, body: unknown): Observable<T> { return this.api.put<T>(this.p(path), body); }
  patch<T>(path: string, body: unknown): Observable<T> { return this.api.patch<T>(this.p(path), body); }
  delete(path: string): Observable<void> { return this.api.delete(this.p(path)); }
  blob(path: string, params?: Record<string, string | number | null | undefined>): Observable<Blob> {
    return this.api.blob(this.p(path), params);
  }
}
