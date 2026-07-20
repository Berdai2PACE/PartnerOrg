---
name: salesforce-doc-init
description: Lance le cadrage initial (Mode 0) d'une nouvelle documentation Salesforce — explore le code, propose un plan, clarifie le périmètre, nettoie l'arborescence, puis crée docs/CONTEXT.md et docs/README.md. À utiliser une seule fois, au tout début d'un nouveau projet de documentation, avant toute rédaction.
---

# Cadrage initial de documentation Salesforce (Mode 0)

Tu vas piloter le cadrage initial d'un projet de documentation Salesforce, en suivant
exactement la séquence ci-dessous. Ne saute aucune étape, en particulier l'étape 3 (questions
de périmètre) : c'est elle qui évite de documenter par erreur des modules hors scope (packages
tiers, reliquats d'un autre projet).

Référence complète et justification de chaque étape (issue d'un projet réel) :
`_docs/templates/00-prompt-cadrage.md` dans ce repo si présent — sinon, applique directement les
étapes ci-dessous, elles sont autonomes.

## Étape 1 — Explorer et proposer un plan

Explore `force-app/main/default/` (structure des dossiers, volumétrie par type de métadonnée,
noms d'objets/flows/classes qui sautent aux yeux). Délègue cette exploration à un sous-agent
avec un prompt précis plutôt que de tout lire toi-même dans la conversation principale.

**Ne rédige aucun document à cette étape.** Propose seulement un plan de documentation de haut
niveau (parties, pas encore le détail de chaque fichier), adapté à ce que tu observes
réellement dans le code — pas un plan générique.

## Étape 2 — Table des matières avant contenu détaillé

Avant d'aller plus loin, propose de créer `docs/README.md` comme table des matières (liste des
documents prévus, sans détailler leur contenu interne) et fais-la valider par l'utilisateur en
premier. Explique explicitement que l'objectif est de valider "quels documents" avant de
discuter "quel contenu dans chaque document" — ça évite de retravailler un plan déjà rédigé en
détail.

## Étape 3 — Questions de périmètre (obligatoire, ne pas sauter)

Repère dans le code tout élément ambigu : packages installés (préfixes avec namespace,
ex. `SBQQ__`), modules dont le nom ne correspond à aucun domaine fonctionnel évoqué par
l'utilisateur, dossiers volumineux et isolés du reste.

Pour chacun, pose une question via l'outil `AskUserQuestion` (pas en texte libre) avec des
options du type : "code custom à documenter" / "package tiers, hors périmètre" / "package
étendu, à documenter partiellement". Ne présume jamais qu'un module fait partie du périmètre
sans validation explicite — un cas réel a montré que deux modules entiers étaient des reliquats
d'un autre projet et auraient été documentés par erreur sans cette question.

Demande aussi, via `AskUserQuestion`, le niveau de profondeur cible (fonctionnel / technique /
les deux) et par quelle partie l'utilisateur souhaite commencer.

## Étape 4 — Nettoyer avant de rédiger

Si des éléments hors périmètre ont été confirmés à l'étape 3, propose de les supprimer de
l'arborescence locale (dossiers fantômes, métadonnées sans fichier associé, modules exclus)
**avant** de commencer la rédaction. Génère la commande de suppression, fais-la valider, exécute,
puis vérifie qu'aucune mention résiduelle ne subsiste dans les fichiers déjà écrits.

## Étape 5 — Itérer sur le découpage détaillé du plan

Maintenant que le périmètre est clair, détaille le plan partie par partie en dialogue avec
l'utilisateur. Pour les domaines qu'il connaît bien, laisse-le proposer directement la liste de
documents. Pour les domaines moins familiers (découverts dans le code), propose toi-même un
découpage et fais-le valider/corriger.

## Étape 6 — Demander (ne pas présumer) la stratégie de session

Pose explicitement la question à l'utilisateur : une conversation par document, ou par grande
partie avec un fichier de contexte partagé, ou autre chose ? Donne ton avis motivé si demandé,
mais ne décide pas à sa place. Une conversation par grande partie + un fichier de contexte
partagé donne en général de meilleurs résultats (cohérence de vocabulaire, pas de relecture
redondante des mêmes fichiers sources), mais le projet peut avoir des contraintes différentes.

## Étape 7 — Créer CONTEXT.md et README.md

Une fois la méthode validée, crée :
- `docs/README.md` à partir de `_docs/templates/README.template.md` si ce fichier existe dans le
  repo, sinon construis-le directement avec la structure validée aux étapes précédentes.
- `docs/CONTEXT.md` à partir de `_docs/templates/CONTEXT.template.md` si présent, sinon crée-le
  avec au minimum ces sections : garde-fou anti-hallucination (voir ci-dessous), décisions de
  vocabulaire, conventions de rédaction, périmètre hors scope, objets/fonctionnalités obsolètes
  à ne pas documenter, zones d'ombre à vérifier en production, index des fichiers source clés,
  avancement par partie.

Inclus impérativement cette règle dans `CONTEXT.md`, dès sa création :

> Toute affirmation descriptive non vérifiable dans le code, les métadonnées, ou un document déjà
> validé doit être marquée ⚠️ à vérifier plutôt qu'affirmée comme un fait.

Termine en indiquant explicitement à l'utilisateur le prompt à utiliser pour démarrer la
prochaine conversation, typiquement :

```
Lis docs/CONTEXT.md et docs/README.md, on démarre la Partie 1
```

Précise aussi que pour les sessions suivantes, le skill `/salesforce-doc-continue` (s'il est
disponible dans ce repo) peut être invoqué en tout début de chaque nouvelle partie pour rappeler
la méthode et le garde-fou anti-hallucination.

## Mode 2 (à mentionner, pas à exécuter ici)

Si l'utilisateur souhaite ensuite documenter en masse des composants répétitifs (Flow, Apex,
Trigger, DLRS, Agentforce), signale que des scripts génériques existent dans
`_docs/templates/scripts/` (à copier vers `scripts/` et adapter — voir
`_docs/templates/checklist-couverture-clouds.md` pour les types de composants non couverts) mais
ne les exécute pas dans le cadre de ce skill : c'est une étape distincte, après que le plan et le
périmètre sont stabilisés.