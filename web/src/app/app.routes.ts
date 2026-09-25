import { Routes } from '@angular/router';
import { authGuard, centerGuard, guestGuard, permissionGuard, superadminGuard } from './core/guards';
import { ShellComponent } from './layout/shell.component';

export const routes: Routes = [
  { path: 'login', canActivate: [guestGuard], loadComponent: () => import('./pages/auth/login.component').then(m => m.LoginComponent) },
  { path: 'register', canActivate: [guestGuard], loadComponent: () => import('./pages/auth/register.component').then(m => m.RegisterComponent) },
  {
    path: '',
    component: ShellComponent,
    canActivate: [authGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },  // redirigé vers /validate sans le droit « rapports »
      { path: 'admin', canActivate: [superadminGuard], loadComponent: () => import('./pages/admin/admin.component').then(m => m.AdminComponent) },
      {
        path: '',
        canActivate: [centerGuard],
        children: [
          { path: 'dashboard', canActivate: [permissionGuard('view_reports')], title: 'Tableau de bord · Lavpro', loadComponent: () => import('./pages/dashboard/dashboard.component').then(m => m.DashboardComponent) },
          { path: 'validate', title: 'Valider un lavage · Lavpro', loadComponent: () => import('./pages/validate/validate.component').then(m => m.ValidateComponent) },
          { path: 'washes', title: 'Lavages · Lavpro', loadComponent: () => import('./pages/washes/washes.component').then(m => m.WashesComponent) },
          { path: 'bookings', title: 'Réservations · Lavpro', loadComponent: () => import('./pages/bookings/bookings.component').then(m => m.BookingsComponent) },
          { path: 'clients', title: 'Clients · Lavpro', loadComponent: () => import('./pages/clients/clients.component').then(m => m.ClientsComponent) },
          { path: 'rewards', canActivate: [permissionGuard('manage_rewards')], title: 'Récompenses · Lavpro', loadComponent: () => import('./pages/rewards/rewards.component').then(m => m.RewardsComponent) },
          { path: 'promotions', canActivate: [permissionGuard('manage_rewards')], title: 'Promotions · Lavpro', loadComponent: () => import('./pages/promotions/promotions.component').then(m => m.PromotionsComponent) },
          { path: 'catalog', canActivate: [permissionGuard('manage_catalog')], title: 'Services & véhicules · Lavpro', loadComponent: () => import('./pages/catalog/catalog.component').then(m => m.CatalogComponent) },
          { path: 'pricing', canActivate: [permissionGuard('manage_catalog')], title: 'Prix & points · Lavpro', loadComponent: () => import('./pages/pricing/pricing.component').then(m => m.PricingComponent) },
          { path: 'team', title: 'Équipe · Lavpro', loadComponent: () => import('./pages/team/team.component').then(m => m.TeamComponent) },
          { path: 'reports', canActivate: [permissionGuard('view_reports')], title: 'Rapports · Lavpro', loadComponent: () => import('./pages/reports/reports.component').then(m => m.ReportsComponent) },
          { path: 'settings', canActivate: [permissionGuard('manage_settings')], title: 'Paramètres · Lavpro', loadComponent: () => import('./pages/settings/settings.component').then(m => m.SettingsComponent) },
        ],
      },
    ],
  },
  { path: '**', redirectTo: '' },
];
