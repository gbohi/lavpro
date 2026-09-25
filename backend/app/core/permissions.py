"""Droits des gestionnaires d'un centre.

Le propriétaire (et le super-admin) a tous les droits. Chaque gestionnaire reçoit une liste de
droits choisie par le propriétaire ; les actions courantes (valider un lavage, scanner un client,
remettre une récompense, gérer la file d'attente et les réservations) sont ouvertes à tous.
"""

PERMISSIONS: dict[str, dict[str, str]] = {
    "manage_team": {
        "label": "Gérer l'équipe",
        "description": "Ajouter, modifier ou retirer des gestionnaires (uniquement avec les droits qu'il possède lui-même).",
    },
    "manage_washers": {"label": "Gérer les laveurs", "description": "Ajouter, modifier, désactiver ou supprimer des laveurs."},
    "manage_catalog": {
        "label": "Modifier les services et les prix",
        "description": "Services, types de véhicules, prix, points gagnés et prix en points.",
    },
    "manage_rewards": {"label": "Gérer récompenses et promotions", "description": "Créer, modifier ou supprimer."},
    "view_reports": {
        "label": "Voir le chiffre d'affaires et les rapports",
        "description": "Tableau de bord, rapports par laveur, export CSV.",
    },
    "adjust_points": {"label": "Ajuster les points des clients", "description": "Offrir ou retirer des points manuellement."},
    "cancel_washes": {"label": "Annuler un lavage", "description": "Supprimer un lavage validé par erreur (points retirés)."},
    "manage_settings": {
        "label": "Modifier les paramètres du centre",
        "description": "Informations, horaires, réservation, fidélité, rappels.",
    },
}

ALL_PERMISSIONS = frozenset(PERMISSIONS)

# Droits attribués par défaut à un nouveau gestionnaire (modifiable par le super-admin : members.default_permissions)
DEFAULT_MANAGER_PERMISSIONS = [
    "manage_washers", "manage_catalog", "manage_rewards", "view_reports", "adjust_points", "manage_settings",
]


def clean(perms: list[str] | None) -> list[str]:
    """Filtre et ordonne une liste de droits selon le catalogue."""
    wanted = set(perms or [])
    return [p for p in PERMISSIONS if p in wanted]
