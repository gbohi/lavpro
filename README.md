# Lavpro

Programme de fidélité et plateforme de gestion pour les centres de lavage automobile.

| Dossier | Techno | Rôle |
|---|---|---|
| [`backend/`](backend) | Python 3.12 · FastAPI · SQLAlchemy 2 · PostgreSQL · Alembic | API REST (auth JWT, fidélité, réservations, rappels, statistiques) |
| [`web/`](web) | Angular CLI 18.0.6 | Espace Pro : back-office des centres et administration de la plateforme |
| [`mobile/`](mobile) | Flutter | **Lavpro** : application des clients |
| [`business/`](business) | Flutter | **Lavpro Business** : application des gérants et gestionnaires de centres |
| [`packages/lavpro_core/`](packages/lavpro_core) | Dart | Code partagé des deux applications (thème, client API, modèles, composants) |

## Tout est paramétrable

Aucune donnée métier n'est codée en dur :

- **Par centre** (Espace Pro) : services, types de véhicules, grille **prix × points** (service × véhicule), récompenses (stock, dates, prérequis écolo), promotions (multiplicateur, bonus, remise, ciblage fidèles/nouveaux/inactifs), horaires, capacité et créneaux, seuils d'affluence, points de bienvenue et de parrainage, définition du « client fidèle », rappels.
- **Plateforme** (super-admin) : niveaux et équivalences du Mode Écolo, règles des rappels intelligents, seuils météo, message de parrainage, catégories de véhicules, modèles de services/véhicules proposés aux nouveaux centres… (table `app_settings`).

## Fonctionnalités

**Utiliser ses points pour un lavage** : deux possibilités, au choix du centre.
- *Récompense « lavage offert »* : liée à un service, éventuellement limitée à certains types de véhicules avec un
  coût en points propre à chacun. Le client l'échange dans l'app, puis le gestionnaire choisit « Payer avec la
  récompense » en validant le lavage : lavage enregistré à 0 (valeur offerte tracée), aucun point gagné, laveur
  crédité, récompense reliée au lavage.
- *Paiement direct en points au comptoir* (à activer dans les paramètres) : prix en points fixé pour chaque service
  et véhicule dans « Prix & points » ; le solde est débité à la validation.

**Clients (mobile)** : inscription unique avec QR code et code membre, soldes de points par centre, historique, récompenses et codes de retrait, centres les plus proches (liste et carte) avec affluence en temps réel, réservation de créneaux, suggestions selon la fréquence de visite et la météo (Open-Meteo), parrainage, Mode Écolo, notifications, thème clair/sombre, interface responsive (téléphone, tablette, desktop).

**Gérants (Lavpro Business, mobile)** : tableau de bord du jour / 7 j / 30 j (lavages, chiffre d'affaires, clients, fidélité, heures d'affluence, point par laveur), réglage de la file d'attente visible en direct par les clients, scan du QR client ou code membre, validation du lavage (véhicule, service, laveur), client de passage, remise des récompenses, réservations du jour (accueillir, absent, annuler), historique des lavages du jour, multi-centres.

**Centres (web)** : inscription du centre, équipe de gestionnaires (propriétaire / gestionnaire), laveurs (sans compte) avec suivi de qui a lavé quoi, validation d'un lavage par scan QR (caméra ou douchette) ou code membre, client de passage, remise des récompenses, file d'attente en direct, tableau de bord (lavages/jour, CA, services populaires, taux de fidélité, heures d'affluence, performance des laveurs), rapports par laveur avec commissions, export CSV.

## Base de données : PostgreSQL

L'API utilise **PostgreSQL** (16 recommandé). Le schéma est géré par des **migrations Alembic**
(`backend/migrations/`), appliquées automatiquement au démarrage de l'API.

```bash
cd backend
alembic upgrade head                                   # appliquer les migrations à la main
alembic revision --autogenerate -m "description"       # après une modification des modèles
```

## Démarrage avec Docker (recommandé)

```bash
cp .env.example .env        # puis changez les mots de passe et LAVPRO_SECRET_KEY
docker compose up -d --build
docker compose exec api python -m app.jobs.seed_demo   # optionnel : données de démonstration
```

- Espace Pro : http://localhost:8080 (nginx relaie `/api` vers l'API)
- API : http://localhost:8000 (documentation sur `/docs`) — adresse à donner à l'application mobile
- Les données PostgreSQL et les images envoyées sont conservées dans des volumes Docker.

## Démarrage sans Docker

```bash
# PostgreSQL : créer un utilisateur et une base "lavpro"
createuser -P lavpro && createdb -O lavpro lavpro

# 1. API (http://localhost:8000)
cd backend
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env              # LAVPRO_DATABASE_URL=postgresql+psycopg://...
python -m app.jobs.seed_demo      # optionnel
uvicorn app.main:app --reload

# 2. Espace Pro (http://localhost:4200)
cd web && npm install && npm start

# 3. Applications mobiles (client et Business)
cd mobile && flutter pub get
flutter run --dart-define=API_URL=http://<ip-de-votre-machine>:8000/api/v1
cd ../business && flutter pub get
flutter run --dart-define=API_URL=http://<ip-de-votre-machine>:8000/api/v1
```

Comptes de démo (après `seed_demo`) : gérant `demo@lavpro.app` / `demo1234`, client `client@lavpro.app` / `demo1234`.
Super-admin : défini par `LAVPRO_SUPERADMIN_EMAIL` / `LAVPRO_SUPERADMIN_PASSWORD` dans `.env`.

Les rappels intelligents s'exécutent via une tâche planifiée : `python -m app.jobs.reminders` (cron, ex. toutes les heures), ou depuis la page Administration.

## Tests

```bash
cd backend && pytest          # parcours complets de l'API, sur la base PostgreSQL lavpro_test
                              # (ou LAVPRO_TEST_DATABASE_URL=postgresql+psycopg://...)
cd web && npx ng build        # compilation Angular
cd mobile && flutter analyze
cd business && flutter analyze
```
