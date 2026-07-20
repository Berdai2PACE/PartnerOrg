---
name: salesforce-doc-update
description: Met à jour la documentation Salesforce existante en traitant un drift détecté (composants modifiés/ajoutés/supprimés en prod depuis la dernière mise à jour de docs/). Lance detect_doc_drift.py si nécessaire. Distinct de /salesforce-doc-continue qui pilote la génération initiale partie par partie.
---

# Mise à jour de la documentation Salesforce (drift)

Ce skill traite un drift de documentation. Il suppose que la génération initiale est terminée
(`docs/CONTEXT.md` et `docs/README.md` existent).

Si ce n'est pas le cas, invoquer d'abord `/salesforce-doc-init` (génération initiale) ou
`/salesforce-doc-continue` (reprise d'une partie en cours).

## Étape 1 — Charger le contexte et s'assurer que le drift est disponible

Lis `docs/CONTEXT.md` et `docs/README.md`.

Vérifie si `docs/DRIFT-DOCUMENTATION.md` existe et est à jour (date de génération cohérente
avec l'état actuel du repo). Si le fichier est absent ou semble ancien, lancer le script
avant de continuer :

```
python3 scripts/detect_doc_drift.py
```

Si le script indique qu'aucun changement n'a été détecté dans `force-app/`, le signaler à
l'utilisateur — la documentation est à jour, rien à traiter.

Sinon, lire `docs/DRIFT-DOCUMENTATION.md` et annoncer à l'utilisateur le nombre d'items
détectés par catégorie (Mode 2 : X fiches à revalider, Y à créer, Z à supprimer — Mode 1 :
N types de métadonnées à examiner) avant de commencer le traitement.

## Étape 2 — Traiter le Mode 2 (mécanique)

Pour chaque item de la section "Mode 2" du drift, dans cet ordre :

**Fiches à revalider (composant modifié, doc existante)**
Relancer le script générateur correspondant sur le seul fichier modifié — pas tout regénérer :
- Flow : `python3 scripts/generate_flow_doc.py <chemin/vers/flow.flow-meta.xml>`
- Apex/Trigger/DLRS : `python3 scripts/generate_apex_doc.py <chemin/vers/fichier>`
- Agentforce : `python3 scripts/generate_agent_doc.py <chemin/vers/bot>`

Après régénération, vérifier si le document d'index correspondant (`20-tech-flows.md`,
`21-tech-apex.md`, `24-tech-agentforce.md`) mentionne ce composant — le mettre à jour si le
rôle ou les dépendances ont changé de façon significative.
**Cocher immédiatement l'item dans `docs/DRIFT-DOCUMENTATION.md`** (`- [ ]` → `- [x]`).

**Fiches à créer (nouveau composant, pas encore documenté)**
Même commande que ci-dessus sur le nouveau fichier source. Ensuite, ajouter une entrée dans le
document d'index correspondant.
**Cocher immédiatement l'item dans `docs/DRIFT-DOCUMENTATION.md`** (`- [ ]` → `- [x]`).

**Fiches à supprimer (composant supprimé en prod)**
Supprimer le fichier `.md` dans `docs/flows/`, `docs/apex/` ou `docs/agents/`. Retirer l'entrée
du document d'index correspondant. Vérifier qu'aucun autre document ne référence ce composant
(grep sur son nom API dans `docs/`).
**Cocher immédiatement l'item dans `docs/DRIFT-DOCUMENTATION.md`** (`- [ ]` → `- [x]`).

## Étape 3 — Traiter le Mode 1 (jugement métier requis)

Pour chaque type de métadonnée listé dans la section "Mode 1" du drift, analyser les fichiers
modifiés et évaluer l'impact sur la doc fonctionnelle existante.

**Pour les fichiers modifiés (statut M) :**
Identifier quel(s) document(s) de `docs/` mentionne(nt) les éléments modifiés (champs, objets,
permission sets, layouts, etc.) et proposer une mise à jour ciblée. Marquer `⚠️ à vérifier`
toute affirmation non vérifiable directement dans le code ou les métadonnées.
Cocher l'item dans `docs/DRIFT-DOCUMENTATION.md` une fois la mise à jour appliquée.

**Pour les fichiers ajoutés (statut A) :**
Ne pas supposer que c'est une évolution mineure. Vérifier si ces ajouts correspondent à :
- Une évolution d'un processus déjà documenté → mise à jour du document existant
- Un nouveau processus métier non couvert → **proposer explicitement la création d'un nouveau
  document** avec un plan court (titre, sections envisagées, niveau F/T/F+T) à valider par
  l'utilisateur avant toute rédaction. Ajouter l'entrée dans `docs/README.md` avec le statut
  🟨 Plan validé une fois approuvé.
Cocher l'item dans `docs/DRIFT-DOCUMENTATION.md` une fois la décision prise (mise à jour ou
nouveau document créé/planifié).

**Pour les fichiers supprimés (statut D) :**
Vérifier si le processus associé est toujours actif (un fichier supprimé du backup peut
signifier une désactivation en prod ou simplement un rename). Demander confirmation avant de
retirer des informations d'un document fonctionnel — ajouter au `docs/BACKLOG-TECHNIQUE.md` si
c'est un élément à décommissionner plutôt qu'une simple mise à jour.
Cocher l'item dans `docs/DRIFT-DOCUMENTATION.md` une fois la décision prise.

## Étape 4 — Garder CONTEXT.md à jour

Toute règle de contenu validée pendant cette session (nouveau terme, exclusion, élément confirmé
comme obsolète) doit être ajoutée à `docs/CONTEXT.md` immédiatement, pas en fin de session.

Tout élément détecté comme legacy/obsolète part dans `docs/BACKLOG-TECHNIQUE.md`, jamais dans
la doc fonctionnelle.

## Étape 5 — Mettre à jour README.md et signaler la fin

Une fois tous les items traités, mettre à jour les statuts dans `docs/README.md` (🔁 → 🟩 pour
les documents mis à jour, 🟨 → 🟩 pour les nouveaux documents créés).

Rappeler à l'utilisateur de committer avec un message incluant "Commit documentation" pour que
le prochain `detect_doc_drift.py` reparte du bon point de référence :

```
git add docs/
git commit -m "Commit documentation — mise à jour drift <date>"
```

## Garde-fou anti-hallucination

Toute affirmation descriptive non vérifiable dans le code, les métadonnées, ou un document déjà
validé doit être marquée `⚠️ à vérifier` plutôt qu'affirmée comme un fait. En cas de doute sur
le comportement d'un composant modifié, vérifier dans le XML source ou via une requête SOQL sur
l'org plutôt que de supposer.