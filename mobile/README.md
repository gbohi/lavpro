# Lavpro — application mobile (Flutter)

Application client Lavpro : carte de fidélité QR, points par centre, récompenses, centres proches
avec affluence en direct, réservation, rappels intelligents, parrainage et Mode Écolo.
Les gérants de centres utilisent l'application dédiée **Lavpro Business** (`../business`).

```bash
flutter pub get
flutter run --dart-define=API_URL=http://192.168.1.10:8000/api/v1
```

Sans `API_URL`, l'app utilise `http://10.0.2.2:8000/api/v1` sur l'émulateur Android et `http://localhost:8000/api/v1` ailleurs.

Architecture : code commun dans `../packages/lavpro_core` (thème, client HTTP, modèles, composants), `lib/data` (dépôt API),
`lib/state` (Riverpod), `lib/ui` (écrans et composants). Navigation : go_router (barre du bas sur téléphone,
rail latéral sur tablette et desktop).
