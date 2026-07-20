# Documentation [NOM DU PROJET] — Index général

> **Statut** : En cours de rédaction
> **Méthode** : Chaque fichier est validé (structure + contenu) avant rédaction
> **Niveaux** : F = Fonctionnel · T = Technique · F+T = Les deux

---

## Partie 1 — Vue d'ensemble

| # | Fichier | Titre | Niveau | Statut |
|---|---------|-------|--------|--------|
| 1.1 | | Architecture globale du projet | F+T | ⬜ À faire |
| 1.2 | | Applications Salesforce et profils utilisateurs | F+T | ⬜ À faire |
| 1.3 | | Glossaire métier et technique | F | ⬜ À faire |

---

## Partie 2 — Modèle de données

*(découper par domaine fonctionnel/cloud, à l'image de 2A/2B/2C sur METACRM-RUN)*

---

## Partie 3 — Processus métier (Fonctionnel)

*(1 fichier par processus métier — voir étape 5 du Mode 0)*

---

## Partie 4 — Référence technique des composants

| # | Fichier | Titre | Niveau | Statut |
|---|---------|-------|--------|--------|
| 4.1 | | Flows : inventaire, déclencheurs, logique et dépendances | T | ⬜ À faire |
| 4.1.* | `flows/` | Fiches détaillées — une fiche par flow | T | ⬜ À faire |
| 4.2 | | Classes Apex, triggers, DLRS | T | ⬜ À faire |
| 4.2.* | `apex/` | Fiches détaillées — une fiche par composant | T | ⬜ À faire |
| 4.3 | | Composants LWC | T | ⬜ À faire |
| 4.4 | | Composants Aura | T | ⬜ À faire |
| 4.5 | | Bots Agentforce | T | ⬜ À faire |
| 4.5.* | `agents/` | Fiches détaillées — une fiche par bot | T | ⬜ À faire |
| 4.6 | | *(si le cloud du projet l'exige — voir checklist couverture)* | T | ⬜ À faire |

---

## Partie 5 — Intégrations externes

*(MuleSoft, Jira, Slack, autres CRM/API tierces selon le projet)*

---

## Partie 6 — Administration et gouvernance

| # | Fichier | Titre | Niveau | Statut |
|---|---------|-------|--------|--------|
| 6.1 | | Permission sets et groupes d'accès | F+T | ⬜ À faire |
| 6.2 | | Profils, rôles et hiérarchie | F | ⬜ À faire |
| 6.3 | | Règles de partage et sécurité des données | F+T | ⬜ À faire |

---

## Légende des statuts

| Icône | Signification |
|-------|---------------|
| ⬜ À faire | Structure et contenu non encore validés |
| 🟨 Plan validé | Structure validée, rédaction en attente |
| 🟩 Rédigé | Document finalisé |
| 🔁 À réviser | Document nécessitant une mise à jour |