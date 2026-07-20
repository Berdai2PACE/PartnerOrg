# Kit de génération de documentation Salesforce

Kit réutilisable extrait de la méthodologie développée sur le projet METACRM-RUN (voir
`docs/METHODOLOGIE.md` de ce projet pour l'historique complet et la justification de chaque
décision). Pensé pour être copié/extrait tel quel vers un nouveau projet Salesforce.

## Contenu

- **`00-prompt-cadrage.md`** — à utiliser en premier sur un nouveau projet. Prompts du Mode 0
  (cadrage initial) : explorer → plan → questions de périmètre → nettoyage → découpage des
  sessions → création de `CONTEXT.md`/`README.md`.
- **`CONTEXT.template.md`** — squelette du fichier de mémoire inter-session, à copier vers
  `docs/CONTEXT.md` du nouveau projet et à laisser Claude remplir au fil du Mode 0.
- **`README.template.md`** — squelette de la table des matières, à copier vers `docs/README.md`.
- **`checklist-couverture-clouds.md`** — à parcourir pendant l'exploration initiale pour savoir
  quels scripts de `scripts/` sont directement utilisables et quels types de composants
  (CPQ, Omnistudio, Experience Cloud...) nécessiteraient un extracteur à écrire.
- **`scripts/`** — les 3 générateurs (Flow, Apex/Trigger/DLRS, Agentforce) pour le Mode 2, plus
  `detect_doc_drift.py` pour la maintenance continue (voir ci-dessous). Génériques sauf
  `detect_app()` dans `generate_flow_doc.py`, marquée `ADAPTER` dans le code — à remplir une fois
  le découpage en domaines fonctionnels du nouveau projet validé.
- **`skill/salesforce-doc-init/`** et **`skill/salesforce-doc-continue/`** — les deux skills
  Claude Code qui pilotent ce kit (voir section dédiée ci-dessous).

## Les deux skills

Claude Code ne détecte les skills que dans `.claude/skills/<nom>/SKILL.md` à la racine du repo
ouvert — un skill rangé seulement dans `_docs/templates/` n'est **pas** appelable tant qu'il
n'est pas aussi copié à cet emplacement. Ce kit garde donc la source de vérité des skills dans
`_docs/templates/skill/`, à copier vers `.claude/skills/` à chaque nouveau projet.

- **`/salesforce-doc-init`** — pilote tout le Mode 0 lui-même : explore le code, propose un plan,
  pose les questions de périmètre via `AskUserQuestion` (le consultant n'a qu'à répondre), nettoie
  l'arborescence si validé, crée `docs/CONTEXT.md` et `docs/README.md` à partir des templates. À
  invoquer une seule fois, en tout début de projet.
- **`/salesforce-doc-continue`** — rappel léger à invoquer en début de chaque nouvelle "Partie".
  Relit `CONTEXT.md`/`README.md`, rappelle la boucle de rédaction (explorer → plan si nouveau →
  rédiger → résumé → MAJ contexte) et le garde-fou anti-hallucination, propose une relecture
  croisée en fin de partie. N'écrit aucun document lui-même — le pilotage reste conversationnel.
- **`/salesforce-doc-update`** — à utiliser pour résoudre un drift après la génération initiale.
  Lance `detect_doc_drift.py` si `DRIFT-DOCUMENTATION.md` est absent, puis traite chaque item :
  régénération ciblée des fiches Mode 2 (Flow/Apex/Agentforce), mise à jour ou création de
  documents fonctionnels Mode 1 (propose explicitement un nouveau document si un processus métier
  non couvert est détecté), mise à jour de `CONTEXT.md` et `README.md` en fin de session.

## Utilisation rapide sur un nouveau projet (parcours consultant)

1. Copier tout le dossier `_docs/templates/` à la racine du nouveau projet.
2. Copier les trois skills vers `.claude/skills/` à la racine du nouveau projet
   (créer `.claude/skills/` s'il n'existe pas) :
   ```
   mkdir -p .claude/skills
   cp -r _docs/templates/skill/salesforce-doc-init .claude/skills/
   cp -r _docs/templates/skill/salesforce-doc-continue .claude/skills/
   cp -r _docs/templates/skill/salesforce-doc-update .claude/skills/
   ```
3. Ouvrir Claude Code dans ce nouveau projet et taper `/salesforce-doc-init`. Suivre les
   questions posées — ne rien préparer en amont.
4. Une fois `docs/CONTEXT.md` et `docs/README.md` créés, démarrer la première conversation de
   rédaction avec le prompt donné par le skill (`Lis docs/CONTEXT.md et docs/README.md, on
   démarre la Partie 1`).
5. Au début de chaque conversation suivante, taper `/salesforce-doc-continue` avant de donner le
   prompt de reprise — le skill rappelle la méthode et les garde-fous sans que le consultant ait
   à s'en souvenir.
6. Pour la doc technique répétitive (Flow/Apex/Agentforce), copier `scripts/` vers le dossier
   `scripts/` du projet, remplir `detect_app()`, tester sur 1 composant, puis scaler par lots de
   5-10 (voir `docs/METHODOLOGIE.md`, Mode 2, pour le détail du protocole).
7. Si `checklist-couverture-clouds.md` révèle des types de composants non couverts (CPQ,
   Omnistudio, LWC en volume...), écrire les extracteurs manquants en suivant le patron des
   scripts existants avant de lancer la génération en masse sur ces types.

## Maintenance continue (après la génération initiale)

Une fois la doc générée, le projet continue d'évoluer. `scripts/detect_doc_drift.py` compare
`force-app/` à l'état au dernier commit ayant touché `docs/`, et génère
`docs/DRIFT-DOCUMENTATION.md` (réécrit à chaque exécution, pas un historique cumulatif) avec :

- **Mode 2** : matching mécanique entre composant source modifié/ajouté/supprimé et fiche `docs/`
  existante — 3 listes (fiches à revalider, à créer, à supprimer/marquer obsolètes).
- **Mode 1** : pas de correspondance fichier↔doc automatique possible ; le script liste juste les
  fichiers `force-app/` modifiés hors Mode 2, regroupés par type de métadonnée (objets, layouts,
  permission sets...), à trier manuellement en session pour juger l'impact sur un doc fonctionnel.

À lancer à la demande (pas de cron par défaut) :

```
python3 scripts/detect_doc_drift.py
```

Usage recommandé : avant une session `/salesforce-doc-continue` de mise à jour, lancer ce script
pour savoir quoi traiter en priorité plutôt que de redécouvrir le drift au hasard.