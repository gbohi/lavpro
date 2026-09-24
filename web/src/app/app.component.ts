import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { OverlaysComponent } from './shared/overlays.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, OverlaysComponent],
  template: `<router-outlet /><app-overlays />`,
})
export class AppComponent {}
