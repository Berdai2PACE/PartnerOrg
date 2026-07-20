# Mode 0 — Prompt de cadrage initial

À utiliser tel quel pour démarrer la documentation d'un nouveau projet Salesforce. Issu de la
session fondatrice du projet METACRM-RUN (voir `docs/METHODOLOGIE.md` de ce projet pour le
détail et la justification de chaque étape).

Ne pas sauter d'étape, surtout pas la 3 (questions de périmètre) : c'est elle qui a détecté des
modules hors périmètre (packages tiers confondus avec du code custom) avant qu'ils ne soient
documentés par erreur.

---

## Étape 1 — Amorçage

```
Tu vas générer la documentation technique et fonctionnelle d'un projet Salesforce.
Le code source est dans force-app/main/default/.
Commence par explorer la structure et propose-moi un plan de documentation
adapté à ce que tu observes dans le code, avant de commencer à rédiger.
```

Attendu : Claude explore (sous-agents + Bash), ne rédige rien, propose un plan de haut niveau.

## Étape 2 — Demander la table des matières en premier

Si Claude part directement sur un plan détaillé, recadrer avec :

```
Avant de commencer, peux-tu écrire un readme ou un fichier d'init avec une table des matières
de tous les documents qui vont être générés ?
Comme méthode, je souhaiterais d'abord qu'on valide ensemble la liste des fichiers, puis que
nous déterminions un par un les éléments présents à l'intérieur.
```

Objectif : séparer "quels documents" (rapide à valider) de "quel contenu dans chaque document"
(coûteux à retravailler si le découpage change après coup).

## Étape 3 — Forcer les questions de périmètre

Si Claude ne pose pas spontanément de question sur des éléments ambigus du code (packages
installés, modules dont le nom ne correspond à aucun cloud connu, dossiers volumineux sans lien
apparent avec le reste), demander explicitement :

```
Avant de valider le plan, y a-t-il des objets, packages ou modules dans le code source dont tu
n'es pas sûr qu'ils fassent partie du périmètre à documenter (ex: package tiers installé,
reliquat d'un autre projet, module désactivé) ? Pose-moi la question pour chacun via des
questions à choix multiples.
```

Ce qui a été détecté ainsi sur METACRM-RUN : deux modules entiers (préfixes `MRC_*` et
`SBQQ__*`) qui étaient des reliquats d'un autre projet, sans rapport avec le périmètre réel —
auraient été documentés par erreur sans cette question.

## Étape 4 — Nettoyer avant de rédiger

Une fois le périmètre confirmé, faire supprimer ce qui est hors scope **avant** la rédaction,
pas après :

```
Peux-tu me générer un prompt afin de supprimer les dossiers correspondants dans l'arborescence ?
Tous les objets sans fichier XML doivent être supprimés (dossiers fantômes laissés par un retrieve
précédent).
```

## Étape 5 — Itérer sur le découpage du plan

Dialogue libre, partie par partie. Pour les domaines fonctionnels que tu connais bien, propose
toi-même la liste (1 fichier par processus métier, par exemple). Pour les domaines moins connus,
laisse Claude proposer un découpage à partir du code et valide/corrige.

## Étape 6 — Demander la recommandation de méthode de session

Ne pas pré-décider la stratégie de découpage des conversations — la demander explicitement,
Claude a accès à la taille réelle de chaque partie pour bien calibrer :

```
Maintenant que nous avons le plan, quelle est ta recommandation pour la rédaction : une
conversation par document ? avec un fichier de contexte alimenté au fur et à mesure ? ou autre
chose ?
```

Réponse obtenue sur METACRM-RUN (probablement reproductible) : une conversation par grande
partie (pas par document, pour la cohérence de vocabulaire et éviter de relire deux fois les
mêmes sources) + un `CONTEXT.md` partagé entre conversations, alimenté après chaque document.

## Étape 7 — Faire créer CONTEXT.md et le prompt d'amorçage des parties

```
Je te laisse créer le CONTEXT.md et je continuerai donc dans une autre conversation.
```

Claude doit livrer, en plus du fichier, le prompt exact à coller en début de chaque conversation
suivante (typiquement `Lis docs/CONTEXT.md et docs/README.md, on démarre la Partie X`).

---

## Garde-fou anti-hallucination à poser dès cette première session

À ajouter dans `CONTEXT.md` dès sa création :

```
Toute affirmation descriptive non vérifiable dans le code, les métadonnées, ou un document déjà
validé doit être marquée ⚠️ à vérifier plutôt qu'affirmée comme un fait.
```

Sans cette règle explicite, des descriptions plausibles mais inventées peuvent se glisser dans
la doc sans qu'on s'en aperçoive (cf. `docs/METHODOLOGIE.md`, incident Semantiweb/TSW).