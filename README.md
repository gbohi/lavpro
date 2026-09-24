# Lavpro

Programme de fidélité et plateforme de gestion pour les centres de lavage automobile.

| Dossier | Techno | Rôle |
|---|---|---|
| [`backend/`](backend) | Python 3.12 · FastAPI · SQLAlchemy 2 | API REST (auth JWT, fidélité, réservations, rappels, statistiques) |
| [`web/`](web) | Angular CLI 18.0.6 | Espace Pro : back-office des centres et administration de la plateforme |
| [`mobile/`](mobile) | Flutter | Application client (et mode gestionnaire pour scanner depuis un téléphone) |

## Tout est paramétrable

Aucune donnée métier n'est codée en dur :

- **Par centre** (Espace Pro) : services, types de véhicules, grille **prix × points** (service × véhicule), récompenses (stock, dates, prérequis écolo), promotions (multiplicateur, bonus, remise, ciblage fidèles/nouveaux/inactifs), horaires, capacité et créneaux, seuils d'affluence, points de bienvenue et de parrainage, définition du « client fidèle », rappels.
- **Plateforme** (super-admin) : niveaux et équivalences du Mode Écolo, règles des rappels intelligents, seuils météo, message de parrainage, catégories de véhicules, modèles de services/véhicules proposés aux nouveaux centres… (table `app_settings`).

## Fonctionnalités

**Clients (mobile)** : inscription unique avec QR code et code membre, soldes de points par centre, historique, récompenses et codes de retrait, centres les plus proches (liste et carte) avec affluence en temps réel, réservation de créneaux, suggestions selon la fréquence de visite et la météo (Open-Meteo), parrainage, Mode Écolo, notifications, thème clair/sombre, interface responsive (téléphone, tablette, desktop).

**Centres (web)** : inscription du centre, équipe de gestionnaires (propriétaire / gestionnaire), laveurs (sans compte) avec suivi de qui a lavé quoi, validation d'un lavage par scan QR (caméra ou douchette) ou code membre, client de passage, remise des récompenses, file d'attente en direct, tableau de bord (lavages/jour, CA, services populaires, taux de fidélité, heures d'affluence, performance des laveurs), rapports par laveur avec commissions, export CSV.

## Démarrage rapide

```bash
# 1. API (http://localhost:8000, documentation sur /docs)
cd backend
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
python -m app.jobs.seed_demo      # optionnel : données de démonstration
uvicorn app.main:app --reload

# 2. Espace Pro (http://localhost:4200)
cd web && npm install && npm start

# 3. Application mobile
cd mobile && flutter pub get
flutter run --dart-define=API_URL=http://<ip-de-votre-machine>:8000/api/v1
```

Comptes de démo (après `seed_demo`) : gérant `demo@lavpro.app` / `demo1234`, client `client@lavpro.app` / `demo1234`.
Super-admin : défini par `LAVPRO_SUPERADMIN_EMAIL` / `LAVPRO_SUPERADMIN_PASSWORD` dans `.env`.

Les rappels intelligents s'exécutent via une tâche planifiée : `python -m app.jobs.reminders` (cron, ex. toutes les heures), ou depuis la page Administration.

## Tests

```bash
cd backend && pytest          # parcours complets de l'API
cd web && npx ng build        # compilation Angular
cd mobile && flutter analyze
```
