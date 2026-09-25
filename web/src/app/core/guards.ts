import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { catchError, map, of } from 'rxjs';
import { AuthService } from './auth.service';
import { Permission } from './models';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (!auth.token()) return router.createUrlTree(['/login']);
  if (auth.user()) return true;
  return auth.loadMe().pipe(
    map(u => (u.memberships.length || u.role === 'superadmin') ? true : router.createUrlTree(['/login'], { queryParams: { denied: 1 } })),
    catchError(() => of(router.createUrlTree(['/login']))),
  );
};

export const centerGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.centerId() ? true : router.createUrlTree(['/admin']);
};

export const superadminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  return auth.isSuperadmin() ? true : inject(Router).createUrlTree(['/']);
};

export const guestGuard: CanActivateFn = () =>
  inject(AuthService).token() ? inject(Router).createUrlTree(['/']) : true;

/** Accès réservé aux gestionnaires disposant de ce droit (sinon : écran de validation des lavages). */
export function permissionGuard(permission: Permission): CanActivateFn {
  return () => {
    const auth = inject(AuthService);
    return auth.can(permission) ? true : inject(Router).createUrlTree(['/validate']);
  };
}
