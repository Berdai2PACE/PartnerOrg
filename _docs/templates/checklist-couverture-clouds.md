# Checklist de couverture par cloud / type de composant

À parcourir en Mode 0 (étape 1, pendant l'exploration de `force-app/main/default/`) pour
identifier quels extracteurs du kit sont directement utilisables tels quels, et lesquels sont à
écrire avant de pouvoir lancer le Mode 2 sur ce projet.

## Couvert par les scripts du kit (`_docs/templates/scripts/`)

| Type de composant | Dossier metadata | Script | Statut |
|---|---|---|---|
| Flow | `flows/` | `generate_flow_doc.py` | Réutilisable tel quel (sauf `detect_app`, à remplir) |
| Classe Apex | `classes/` | `generate_apex_doc.py` | Réutilisable tel quel |
| Trigger Apex | `triggers/` | `generate_apex_doc.py` | Réutilisable tel quel |
| Règle DLRS (package `dlrs`) | `customMetadata/*.md-meta.xml` | `generate_apex_doc.py` | Réutilisable tel quel — uniquement si le projet utilise le package DLRS |
| Bot Agentforce | `genAiPlannerBundles/`, `botVersions/` (selon version) | `generate_agent_doc.py` | À revalider — la structure des métadonnées Agentforce évolue vite d'une release Salesforce à l'autre |

## Probablement pas couvert — à vérifier si présent dans le projet cible

Si l'exploration Mode 0 révèle un volume significatif de l'un de ces éléments, prévoir d'écrire
un extracteur dédié sur le même patron (extraction XML/JSON factuelle → prompt structuré →
`claude -p` → règle "À compléter" si donnée absente) avant de lancer le Mode 2 sur ce type :

- **LWC** (`lwc/`) — pas de script dédié sur METACRM-RUN (un seul composant, documenté à la main)
- **Aura** (`aura/`) — idem, documenté à la main
- **CPQ** (`SBQQ__*`, Product Rules, Price Rules) — absent du périmètre METACRM-RUN (exclu en
  Mode 0 comme reliquat d'un autre projet), aucun extracteur existant
- **Omnistudio** (OmniScripts, DataRaptors, Integration Procedures, FlexCards) — absent du
  périmètre source, aucun extracteur existant. Format de métadonnées très différent des Flows
  classiques (souvent stocké en JSON dans des champs longs plutôt qu'en XML structuré)
- **Experience Cloud** (sites, pages, composants LWC spécifiques au portail) — absent du
  périmètre source
- **Service Cloud** (Omni-Channel, Macros, Quick Text, Entitlements) — absent du périmètre source
- **Validation Rules / Workflow Rules / Process Builder** — non traités spécifiquement (process
  builder et workflow rules sont des automatisations legacy, à signaler comme telles si présentes
  plutôt que documentées comme des Flows modernes)
- **Reports / Dashboards** — traités manuellement en Mode 1 sur METACRM-RUN (pas de script), via
  parsing XML ad hoc en Bash/Python inline pendant la session — voir `docs/METHODOLOGIE.md` pour
  le pattern (session M&A, doc 19)

## Avant de lancer le Mode 2 sur un nouveau type de composant

1. Repérer 2-3 exemples représentatifs du composant dans le code source
2. Lire leur structure XML/JSON pour identifier les champs factuels exploitables (pas de
   logique métier à deviner, uniquement ce qui est extractible mécaniquement)
3. Écrire l'extracteur en suivant le patron des 3 scripts existants : fonctions `extract_*`
   séparées, `build_prompt()` qui n'injecte que des données extraites, règle "À compléter" pour
   tout champ non déterminable
4. Tester sur la fiche la plus complexe trouvée (pas la plus simple) avant de lancer en masse