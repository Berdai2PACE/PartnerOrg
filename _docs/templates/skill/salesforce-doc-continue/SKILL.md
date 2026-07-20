---
name: salesforce-doc-continue
description: Rappel léger à invoquer en début de chaque session de rédaction de documentation Salesforce (une nouvelle "Partie"), une fois le cadrage initial (salesforce-doc-init) déjà fait. Relit le contexte existant et rappelle la méthode de rédaction et le garde-fou anti-hallucination. N'écrit aucun document lui-même.
---

# Reprise d'une session de documentation Salesforce (Mode 1)

Ce skill ne pilote pas la rédaction à ta place — il prépare la session pour qu'elle démarre
sans friction et sans oublier les règles déjà validées avec l'utilisateur.

## Étape 1 — Charger le contexte

Lis intégralement `docs/CONTEXT.md` et `docs/README.md`. S'ils n'existent pas, arrête-toi et
indique à l'utilisateur d'invoquer d'abord `/salesforce-doc-init` — ce skill suppose que le
cadrage initial est déjà fait.

Identifie dans `docs/README.md` la prochaine partie/document non encore marqué 🟩 Rédigé.

## Étape 2 — Rappeler la boucle de travail, document par document

Pour chaque document à rédiger dans cette session, applique cette boucle (ne pas l'expliquer à
l'utilisateur à chaque fois, juste l'appliquer) :

1. **Explorer** le code source nécessaire à ce document — déléguer à un sous-agent avec un
   prompt d'extraction ciblé plutôt que de lire le XML/code brut dans la conversation
   principale.
2. **Vérifier le terrain en cas de doute** plutôt que de supposer — requête SOQL sur l'org si un
   alias est disponible, ou grep ciblé dans le code, avant d'écrire une affirmation factuelle
   incertaine.
3. Si le document est structurant ou nouveau dans son genre : proposer un plan court (sections
   envisagées) + 2-3 questions ciblées avant de rédiger, attendre validation.
4. Si le document suit un pattern déjà établi dans cette partie : rédiger directement, puis
   livrer un résumé court en bullet points (pas le contenu brut collé dans le chat), proposer la
   suite.
5. **Mettre à jour `docs/CONTEXT.md` et `docs/README.md` immédiatement après ce document**, pas
   en fin de session — en particulier toute règle de contenu validée par l'utilisateur
   (exclusion, terminologie, élément obsolète à ne pas documenter).
6. Tout élément détecté comme legacy/obsolète/à corriger part dans `docs/BACKLOG-TECHNIQUE.md`
   (le créer s'il n'existe pas), jamais dans la doc fonctionnelle elle-même.

## Étape 3 — Garde-fou anti-hallucination

Rappelle-toi, et applique sans qu'il soit nécessaire que l'utilisateur le redemande : toute
affirmation descriptive qui n'est pas vérifiable dans le code, les métadonnées, ou un document
déjà validé doit être marquée `⚠️ à vérifier` plutôt qu'affirmée comme un fait. Si l'utilisateur
questionne une affirmation ("d'où tiens-tu ça ?"), c'est le signe qu'une hallucination a pu se
glisser — corriger immédiatement en cherchant une source réelle plutôt qu'en reformulant la même
invention.

## Étape 4 — Fin de partie

Quand tous les documents prévus pour cette partie sont rédigés, propose explicitement une
relecture croisée : redemander à un sous-agent de relire tous les documents déjà écrits (pas
seulement ceux de cette partie) pour détecter contradictions, doublons, ou informations qui
auraient dû être propagées rétroactivement vers des documents antérieurs. Ce n'est pas
spontané pour l'utilisateur, donc propose-le toi-même plutôt que d'attendre qu'il le demande.