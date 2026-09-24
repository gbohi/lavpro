import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, throwError } from 'rxjs';
import { AuthService } from './auth.service';
import { ToastService } from './toast.service';

export function errorMessage(err: unknown): string {
  if (err instanceof HttpErrorResponse) {
    const detail = err.error?.detail;
    if (typeof detail === 'string') return detail;
    if (Array.isArray(detail) && detail.length) {
      const d = detail[0];
      return `${(d.loc ?? []).slice(1).join('.')} : ${d.msg}`;
    }
    if (err.status === 0) return 'Serveur injoignable. Vérifiez votre connexion.';
    return `Erreur ${err.status}`;
  }
  return 'Une erreur est survenue';
}

export const httpInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const toast = inject(ToastService);
  const token = auth.token();
  const authReq = token ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : req;
  return next(authReq).pipe(
    catchError((err: HttpErrorResponse) => {
      if (err.status === 401 && token) {
        auth.logout();
      } else if (!req.headers.has('X-Silent')) {
        toast.error(errorMessage(err));
      }
      return throwError(() => err);
    }),
  );
};
