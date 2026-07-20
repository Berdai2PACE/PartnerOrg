#!/usr/bin/env python3
"""
Génère la fiche Markdown d'une classe Apex, d'un trigger ou d'une config DLRS.

Usage:
    python3 generate_apex_doc.py <chemin/vers/fichier.cls|.trigger|.md-meta.xml>

Sortie:
    docs/apex/<NomDuFichier>.md
"""

import sys
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
OUTPUT_DIR = REPO_ROOT / "docs" / "apex"
CLASSES_DIR  = REPO_ROOT / "force-app" / "main" / "default" / "classes"
TRIGGERS_DIR = REPO_ROOT / "force-app" / "main" / "default" / "triggers"
CUSTOM_META_DIR = REPO_ROOT / "force-app" / "main" / "default" / "customMetadata"
FLOWS_DIR    = REPO_ROOT / "force-app" / "main" / "default" / "flows"

NS = "http://soap.sforce.com/2006/04/metadata"


# ─── Détection du type de fichier ────────────────────────────────────────────

def detect_kind(path: Path) -> str:
    if path.suffix == ".cls":
        return "apex"
    if path.suffix == ".trigger":
        return "trigger"
    if path.name.endswith(".md-meta.xml"):
        return "dlrs"
    raise ValueError(f"Type de fichier non reconnu : {path}")


# ─── Extraction Apex ──────────────────────────────────────────────────────────

def extract_apex_meta(source: str, name: str) -> dict:
    """Extrait les métadonnées clés d'une classe Apex."""
    meta = {"name": name, "sharing": "", "invocable_method": None, "inner_classes": [], "public_methods": []}

    # Sharing
    m = re.search(r'\b(with sharing|without sharing|inherited sharing)\b', source, re.IGNORECASE)
    if m:
        meta["sharing"] = m.group(1).lower()

    # @InvocableMethod
    inv = re.search(r'@InvocableMethod\s*\([^)]*label\s*=\s*\'([^\']+)\'[^)]*\)', source, re.IGNORECASE)
    if inv:
        meta["invocable_method"] = inv.group(1)

    # Inner classes
    meta["inner_classes"] = re.findall(r'public\s+class\s+(\w+)', source)

    # Public/private static methods (top-level)
    meta["public_methods"] = re.findall(r'(?:public|private)\s+(?:static\s+)?[\w<>]+\s+(\w+)\s*\(', source)

    return meta


def find_calling_flows(class_name: str) -> list[str]:
    """Retourne les noms API des flows qui référencent la classe Apex."""
    calling = []
    if not FLOWS_DIR.exists():
        return calling
    for flow_file in sorted(FLOWS_DIR.glob("*.flow-meta.xml")):
        content = flow_file.read_text(encoding="utf-8")
        if class_name in content:
            calling.append(flow_file.name.replace(".flow-meta.xml", ""))
    return calling


def find_test_class(name: str) -> str | None:
    """Cherche une classe de test associée (NomClasseTest.cls)."""
    candidates = [
        CLASSES_DIR / f"{name}Test.cls",
        CLASSES_DIR / f"{name}_Test.cls",
    ]
    for c in candidates:
        if c.exists():
            return c.read_text(encoding="utf-8")
    return None


def build_apex_prompt(name: str, source: str, meta: dict, test_source: str | None, calling_flows: list[str]) -> str:
    test_section = f"\n## Code de test\n\n```apex\n{test_source}\n```" if test_source else ""
    flows_str = "\n".join(f"- `{f}`" for f in calling_flows) if calling_flows else "Aucun."

    return f"""Tu es expert Salesforce. Tu dois rédiger la fiche technique d'une classe Apex en français, en Markdown.

## Code source

```apex
{source}
```{test_section}

## Format de sortie attendu

Génère UNIQUEMENT le contenu Markdown ci-dessous, sans balise de code englobante, sans commentaire avant ou après.

Règle de formatage obligatoire : tous les noms API (noms de variables, champs Salesforce, noms d'objets custom, noms de classes Apex, noms de flows, noms de méthodes, annotations) doivent être écrits en `code` (backticks).

### `{name}`

**Type** : Classe Apex (ou : Action invocable / Helper / ...)

**Sharing** : `{meta.get("sharing") or "non spécifié"}`

**Rôle** : Une phrase claire décrivant ce que fait cette classe du point de vue fonctionnel.

**Méthode invocable** : (section à inclure uniquement si `@InvocableMethod` est présent)
- Label Flow : …
- Signature : `nomMéthode(List<Request>) : List<Result>`
- Paramètres d'entrée : liste des `@InvocableVariable` de la classe `Request` / `Input` avec leur type et rôle
- Paramètres de sortie : liste des `@InvocableVariable` de la classe `Result` / `Output` avec leur type et rôle

**Logique** :
Décris chaque méthode publique et privée dans l'ordre, avec suffisamment de détail pour qu'un développeur puisse déboguer sans ouvrir la classe.

Pour chaque méthode, mentionne :
- Le rôle de la méthode
- Les SOQL exécutés (objets requêtés, filtres, champs sélectionnés)
- Les DML exécutés (insert / update / delete sur quel objet)
- Les appels à d'autres méthodes ou classes
- Les cas d'erreur gérés

**Classes internes** : (section à inclure uniquement s'il y a des inner classes)
| Classe | Rôle |
|--------|------|
| `…` | … |

**Couverture de test** : (section à inclure uniquement si une classe de test est fournie)
Liste les scénarios couverts par la classe de test.
- `testNomDuTest` — ce que ce test vérifie

**Flows appelants** :
{flows_str}

**Dépendances** : classes Apex, objets Salesforce, Platform Events référencés. Si aucune dépendance externe, écrire "Aucune."
"""


# ─── Extraction Trigger ───────────────────────────────────────────────────────

def build_trigger_prompt(name: str, source: str) -> str:
    return f"""Tu es expert Salesforce. Tu dois rédiger la fiche technique d'un trigger Apex en français, en Markdown.

## Code source

```apex
{source}
```

## Format de sortie attendu

Génère UNIQUEMENT le contenu Markdown ci-dessous, sans balise de code englobante, sans commentaire avant ou après.

Règle de formatage obligatoire : tous les noms API doivent être écrits en `code` (backticks).

### `{name}`

**Type** : Trigger Apex

**Objet** : …

**Événements** : liste des événements déclarés (before insert, after update…)

**Rôle** : Une phrase décrivant ce que fait ce trigger.

**Logique** :
Décris ce que fait le trigger. Si le trigger délègue à un service (ex: `dlrs.RollupService.triggerHandler()`), explique ce que ce service fait dans ce contexte.

**Dépendances** : classes ou packages référencés.
"""


# ─── Extraction DLRS (Custom Metadata) ───────────────────────────────────────

def parse_dlrs_meta(path: Path) -> dict:
    tree = ET.parse(path)
    root = tree.getroot()

    def val(field_name):
        for v in root.findall(f"{{{NS}}}values"):
            f = v.find(f"{{{NS}}}field")
            if f is not None and f.text == field_name:
                value_el = v.find(f"{{{NS}}}value")
                if value_el is not None and value_el.text:
                    return value_el.text.strip()
        return ""

    label_el = root.find(f"{{{NS}}}label")
    return {
        "label":            label_el.text.strip() if label_el is not None else path.stem,
        "active":           val("dlrs__Active__c"),
        "operation":        val("dlrs__AggregateOperation__c"),
        "result_field":     val("dlrs__AggregateResultField__c"),
        "field_to_agg":     val("dlrs__FieldToAggregate__c"),
        "child_object":     val("dlrs__ChildObject__c"),
        "parent_object":    val("dlrs__ParentObject__c"),
        "relationship":     val("dlrs__RelationshipField__c"),
        "criteria":         val("dlrs__RelationshipCriteria__c"),
        "criteria_fields":  val("dlrs__RelationshipCriteriaFields__c"),
        "calc_mode":        val("dlrs__CalculationMode__c"),
        "sharing_mode":     val("dlrs__CalculationSharingMode__c"),
    }


def build_dlrs_prompt(api_name: str, meta: dict) -> str:
    return f"""Tu es expert Salesforce. Tu dois rédiger la fiche technique d'une règle de rollup DLRS (Declarative Lookup Rollup Summaries) en français, en Markdown.

## Données extraites

- **Nom API** : {api_name}
- **Label** : {meta['label']}
- **Actif** : {meta['active'] or 'false'}
- **Objet enfant** (source) : `{meta['child_object']}`
- **Objet parent** (cible) : `{meta['parent_object']}`
- **Champ de relation** : `{meta['relationship']}`
- **Champ agrégé** : `{meta['field_to_agg']}`
- **Opération** : {meta['operation']}
- **Champ résultat** : `{meta['result_field']}`
- **Critère de filtre** : {meta['criteria'] or '(aucun)'}
- **Champs de critère** : {meta['criteria_fields'] or '(aucun)'}
- **Mode de calcul** : {meta['calc_mode']}
- **Mode de partage** : {meta['sharing_mode']}

## Format de sortie attendu

Génère UNIQUEMENT le contenu Markdown ci-dessous, sans balise de code englobante, sans commentaire avant ou après.

Règle de formatage obligatoire : tous les noms API doivent être écrits en `code` (backticks).

### `{api_name}`

**Type** : Règle de rollup DLRS (`dlrs__LookupRollupSummary2__mdt`)

**Label** : …

**Statut** : Actif / Inactif

**Rôle** : Une phrase décrivant ce que calcule cette règle.

**Configuration** :
| Paramètre | Valeur |
|-----------|--------|
| Objet enfant | … |
| Objet parent | … |
| Champ de relation | … |
| Champ agrégé | … |
| Opération | … |
| Champ résultat | … |
| Filtre | … |
| Mode de calcul | … |
| Mode de partage | … |

**Trigger associé** : `dlrs_AccountTrigger` — ce trigger est nécessaire pour que le calcul en mode `Realtime` se déclenche sur les modifications de l'objet parent.

**Dépendances** : objet parent, objet enfant, champ résultat.
"""


# ─── Appel Claude CLI ─────────────────────────────────────────────────────────

def call_claude(prompt: str, name: str) -> str:
    print(f"⏳  Appel à Claude pour {name}…", file=sys.stderr)
    result = subprocess.run(
        ["claude", "-p", prompt],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Erreur Claude CLI :\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


# ─── Point d'entrée ──────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_apex_doc.py <fichier.cls|.trigger|.md-meta.xml>", file=sys.stderr)
        sys.exit(1)

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"Fichier introuvable : {path}", file=sys.stderr)
        sys.exit(1)

    kind = detect_kind(path)
    name = path.name.split(".")[0]  # retire toutes les extensions

    if kind == "apex":
        source = path.read_text(encoding="utf-8")
        meta = extract_apex_meta(source, name)
        test_source = find_test_class(name)
        calling_flows = find_calling_flows(name)
        prompt = build_apex_prompt(name, source, meta, test_source, calling_flows)

    elif kind == "trigger":
        source = path.read_text(encoding="utf-8")
        prompt = build_trigger_prompt(name, source)

    elif kind == "dlrs":
        dlrs_meta = parse_dlrs_meta(path)
        # Nom API = NomType.NomRecord (ex: dlrs__LookupRollupSummary2.Account_CA)
        type_name = path.name.replace(".md-meta.xml", "")
        name = type_name
        prompt = build_dlrs_prompt(name, dlrs_meta)

    content = call_claude(prompt, name)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_file = OUTPUT_DIR / f"{name}.md"
    out_file.write_text(content, encoding="utf-8")
    print(f"✅  Fiche générée : {out_file}", file=sys.stderr)
    print(str(out_file))


if __name__ == "__main__":
    main()