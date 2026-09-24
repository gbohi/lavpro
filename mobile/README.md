# Lavpro — application mobile (Flutter)

Application client Lavpro : carte de fidélité QR, points par centre, récompenses, centres proches
avec affluence en direct, réservation, rappels intelligents, parrainage et Mode Écolo.
Les gestionnaires disposent d'un « Mode gestionnaire » pour scanner un client et valider un lavage.

```bash
flutter pub get
flutter run --dart-define=API_URL=http://192.168.1.10:8000/api/v1
```

Sans `API_URL`, l'app utilise `http://10.0.2.2:8000/api/v1` sur l'émulateur Android et `http://localhost:8000/api/v1` ailleurs.

Architecture : `lib/core` (thème, client HTTP, responsive), `lib/models`, `lib/data` (dépôt API),
`lib/state` (Riverpod), `lib/ui` (écrans et composants). Navigation : go_router (barre du bas sur téléphone,
rail latéral sur tablette et desktop).
