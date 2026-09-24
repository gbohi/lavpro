# Lavpro Business (Flutter)

Application mobile des gérants et gestionnaires de centres de lavage Lavpro.

- **Activité** : chiffres du jour, de 7 ou 30 jours (lavages, CA, clients, fidélité, points), heures
  d'affluence, point par laveur, services les plus demandés ; réglage de la file d'attente (+/−)
  visible en temps réel par les clients.
- **Scanner** : QR code du client (caméra) ou code membre, client de passage, remise d'une récompense
  par son code de retrait.
- **Validation** : type de véhicule, service (prix et points affichés), laveur, immatriculation ;
  réservation du client et récompenses à remettre détectées automatiquement.
- **Réservations** du jour : accueillir (valide le lavage), client absent, annuler, appeler.
- **Lavages** du jour : qui a lavé quoi, pour qui, validé par qui.
- Multi-centres, thème clair/sombre, interface adaptée téléphone et tablette.

Seuls les comptes rattachés à un centre (propriétaire ou gestionnaire) peuvent se connecter. La configuration
(prix et points, récompenses, promotions, équipe…) se fait dans l'Espace Pro web.

```bash
flutter pub get
flutter run --dart-define=API_URL=http://192.168.1.10:8000/api/v1
```

Identifiants : `app.lavpro.business` (Android et iOS).
