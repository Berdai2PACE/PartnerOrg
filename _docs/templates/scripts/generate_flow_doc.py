#!/usr/bin/env python3
"""
Génère la fiche Markdown d'un Flow Salesforce.

Usage:
    python3 generate_flow_doc.py <chemin/vers/flow.flow-meta.xml>

Sortie:
    docs/flows/<NomDuFlow>.md
"""

import sys
import os
import re
import json
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from collections import defaultdict

NS = "http://soap.sforce.com/2006/04/metadata"

REPO_ROOT = Path(__file__).parent.parent
OUTPUT_DIR = REPO_ROOT / "docs" / "flows"

# ─── Helpers ──────────────────────────────────────────────────────────────────

def tag(name):
    return f"{{{NS}}}{name}"

def txt(el, path, default=""):
    node = el.find(f"{{{NS}}}{path}")
    return node.text.strip() if node is not None and node.text else default

def all_txt(el, path):
    return [n.text.strip() for n in el.findall(f"{{{NS}}}{path}") if n.text]


# ─── Convention de nommage ────────────────────────────────────────────────────
# ADAPTER : ceci reflète une convention de nommage d'équipe (suffixe = type de
# déclencheur), pas un standard Salesforce. Si le projet cible suit une autre
# convention (ou aucune), adapter SUFFIX_MAP ou vider cette fonction.

SUFFIX_MAP = {
    "BSTF":  "Record-Triggered Before Save",
    "ASTF":  "Record-Triggered After Save",
    "BDTF":  "Record-Triggered Before Delete",
    "ARTF":  "Record-Triggered After Save (create only)",
    "SCRF":  "Screen Flow",
    "SCHF":  "Scheduled Flow",
    "ALF":   "Autolaunched Flow (invocable)",
    "SUBFLOW": "Subflow (réutilisable)",
}

def decode_suffix(api_name):
    for suffix, label in SUFFIX_MAP.items():
        if api_name.upper().endswith(suffix) or f"_{suffix}_" in api_name.upper() or api_name.upper().startswith(suffix):
            return label
    return ""


# ─── Application détectée depuis le préfixe ──────────────────────────────────
# ADAPTER : spécifique au projet — remplir une fois le découpage en domaines
# fonctionnels validé pendant le Mode 0 (cadrage). Voir 00-prompt-cadrage.md.
# Exemple de structure à reproduire (préfixes observés sur le projet source) :
#
# APP_PREFIX_MAP = {
#     "APPMA":  "APPMA",
#     ("Synergy_Bot", "Platform_Event_Synergie"): "MetaCRM / Synergies",
#     "Agent_Action": "Agentforce",
#     "Utility_": "Utilitaire",
#     ("DemoFlow", "TEST_"): "⚠️ Non-production (démo / test)",
# }

def detect_app(api_name):
    # TODO : remplir avec les préfixes/conventions du projet cible une fois le
    # plan de documentation validé (Mode 0, étape 5).
    return ""


# ─── Extraction des nœuds ────────────────────────────────────────────────────

NODE_TYPES = [
    "assignments", "decisions", "loops", "recordCreates", "recordLookups",
    "recordUpdates", "recordDeletes", "actionCalls", "subflows",
    "collectionProcessors", "transforms", "screens",
]

def extract_formulas(root):
    """Extrait toutes les formules définies dans le flow."""
    formulas = []
    for el in root.findall(tag("formulas")):
        formulas.append({
            "name":       txt(el, "name"),
            "data_type":  txt(el, "dataType"),
            "expression": txt(el, "expression"),
        })
    return formulas


def extract_nodes(root):
    """Retourne une liste de dicts décrivant chaque nœud du flow."""
    nodes = []
    for node_type in NODE_TYPES:
        for el in root.findall(tag(node_type)):
            name  = txt(el, "name")
            label = txt(el, "label") or name
            desc  = txt(el, "description")

            info = {
                "type":  node_type,
                "name":  name,
                "label": label,
                "desc":  desc,
            }

            if node_type == "decisions":
                rules = []
                for rule in el.findall(tag("rules")):
                    rule_label = txt(rule, "label") or txt(rule, "name")
                    conds = []
                    for c in rule.findall(tag("conditions")):
                        left  = txt(c, "leftValueReference")
                        op    = txt(c, "operator")
                        right_el = c.find(f"{{{NS}}}rightValue")
                        right = ""
                        if right_el is not None:
                            for child in right_el:
                                right = child.text or ""
                        conds.append(f"{left} {op} {right}")
                    logic = txt(rule, "conditionLogic", "and")
                    rules.append({"label": rule_label, "conditions": conds, "logic": logic})
                default_label = txt(el, "defaultConnectorLabel") or "Défaut"
                info["rules"] = rules
                info["default_label"] = default_label

            elif node_type == "actionCalls":
                info["action_name"] = txt(el, "actionName")
                info["action_type"] = txt(el, "actionType")
                inputs  = [f"{txt(p,'name')} ← {_param_value(p)}" for p in el.findall(tag("inputParameters"))]
                outputs = [f"{txt(p,'assignToReference')} ← {txt(p,'name')}" for p in el.findall(tag("outputParameters"))]
                info["inputs"]  = inputs
                info["outputs"] = outputs

            elif node_type == "subflows":
                info["flow_name"] = txt(el, "flowName")
                inputs = [f"{txt(p,'name')} ← {_param_value(p)}" for p in el.findall(tag("inputAssignments"))]
                info["inputs"] = inputs

            elif node_type == "recordLookups":
                info["object"]   = txt(el, "object")
                info["filters"]  = _extract_filters(el)
                info["first_only"] = txt(el, "getFirstRecordOnly") == "true"

            elif node_type in ("recordCreates", "recordUpdates", "recordDeletes"):
                info["object"]   = txt(el, "object")
                fields = []
                for ia in el.findall(tag("inputAssignments")):
                    field = txt(ia, "field")
                    val   = _assignment_value(ia)
                    fields.append(f"{field} ← {val}")
                ref = txt(el, "inputReference")
                if ref:
                    fields.append(f"(référence SObject : {ref})")
                info["fields"] = fields

            elif node_type == "assignments":
                items = []
                for ai in el.findall(tag("assignmentItems")):
                    target = txt(ai, "assignToReference")
                    op     = txt(ai, "operator")
                    val    = _assignment_value(ai)
                    items.append(f"{target} {op} {val}")
                info["items"] = items

            elif node_type == "loops":
                info["collection"] = txt(el, "collectionReference")

            elif node_type == "collectionProcessors":
                info["subtype"]     = txt(el, "elementSubtype")
                info["collection"]  = txt(el, "collectionReference")
                info["conditions"]  = [
                    f"{txt(c,'leftValueReference')} {txt(c,'operator')} {_right_value(c)}"
                    for c in el.findall(tag("conditions"))
                ]

            elif node_type == "transforms":
                info["data_type"] = txt(el, "dataType")

            nodes.append(info)
    return nodes


def _right_value(el):
    rv = el.find(tag("rightValue"))
    if rv is None:
        return ""
    for child in rv:
        return child.text or ""
    return ""

def _param_value(el):
    v = el.find(tag("value"))
    if v is None:
        return ""
    for child in v:
        return child.text or ""
    return ""

def _assignment_value(el):
    v = el.find(tag("value"))
    if v is None:
        return ""
    for child in v:
        return child.text or ""
    return ""

def _filter_value(el):
    """Extrait la valeur d'un filtre — gère <value> (filters) et <rightValue> (conditions)."""
    for tag_name in ("value", "rightValue"):
        v = el.find(tag(tag_name))
        if v is not None:
            for child in v:
                return child.text or ""
    return ""

def _extract_filters(el):
    filters = []
    for f in el.findall(tag("filters")):
        field = txt(f, "field")
        op    = txt(f, "operator")
        val   = _filter_value(f)
        filters.append(f"{field} {op} {val!r}")
    return filters


# ─── Extraction des champs lus / écrits ──────────────────────────────────────

def extract_field_usage(root, nodes):
    """Construit le tableau des champs lus et écrits."""
    reads  = []
    writes = []

    for n in nodes:
        if n["type"] == "recordLookups":
            obj = n.get("object", "")
            for f in n.get("filters", []):
                reads.append((obj, f.split()[0]))

        elif n["type"] == "recordCreates":
            obj = n.get("object", "")
            for f in n.get("fields", []):
                field = f.split(" ← ")[0]
                if not field.startswith("("):
                    writes.append((obj, field))

        elif n["type"] == "recordUpdates":
            obj = n.get("object", "")
            for f in n.get("fields", []):
                field = f.split(" ← ")[0]
                if not field.startswith("("):
                    writes.append((obj, field))

    # Champs écrits en Before Save via $Record
    for el in root.findall(tag("recordUpdates")):
        ref = txt(el, "inputReference")
        if ref == "$Record":
            obj_el = root.find(f".//{{{NS}}}start/{{{NS}}}object")
            obj = obj_el.text if obj_el is not None else ""
            for ia in el.findall(tag("inputAssignments")):
                writes.append((obj, txt(ia, "field")))

    # Déduplication tout en préservant l'ordre
    seen_r, seen_w = set(), set()
    reads_u, writes_u = [], []
    for item in reads:
        if item not in seen_r:
            seen_r.add(item)
            reads_u.append(item)
    for item in writes:
        if item not in seen_w:
            seen_w.add(item)
            writes_u.append(item)

    return reads_u, writes_u


# ─── Extraction des dépendances ──────────────────────────────────────────────

def extract_dependencies(nodes):
    deps = {"subflows": [], "apex": [], "platform_events": []}
    for n in nodes:
        if n["type"] == "subflows":
            deps["subflows"].append(n.get("flow_name", ""))
        elif n["type"] == "actionCalls" and n.get("action_type") == "apex":
            deps["apex"].append(n.get("action_name", ""))
    return deps


# ─── Extraction des métadonnées du start ─────────────────────────────────────

def extract_start(root):
    start = root.find(tag("start"))
    if start is None:
        return {}
    info = {
        "trigger_type":       txt(start, "triggerType"),
        "object":             txt(start, "object"),
        "record_trigger_type": txt(start, "recordTriggerType"),
        "filter_formula":     txt(start, "filterFormula"),
        "flow_run_as":        txt(start, "flowRunAsUser"),
    }
    sched = start.find(tag("schedule"))
    if sched is not None:
        info["schedule"] = {
            "frequency":  txt(sched, "frequency"),
            "start_date": txt(sched, "startDate"),
            "start_time": txt(sched, "startTime"),
        }
    filters = _extract_filters(start)
    if filters:
        info["filters"] = filters
    return info


# ─── Construction du prompt pour Claude ──────────────────────────────────────

def build_prompt(api_name, label, description, app, start_info, nodes, reads, writes, deps, status, formulas):
    trigger_type = start_info.get("trigger_type", "")
    obj          = start_info.get("object", "")
    rec_trigger  = start_info.get("record_trigger_type", "")
    filter_formula = start_info.get("filter_formula", "")
    filters_start  = start_info.get("filters", [])
    schedule       = start_info.get("schedule", {})

    # Résumé des nœuds pour le prompt
    nodes_summary = []
    for n in nodes:
        line = f"- [{n['type']}] {n['label']}"
        if n.get("desc"):
            line += f" : {n['desc']}"
        if n["type"] == "decisions":
            for r in n.get("rules", []):
                logic = r.get("logic", "and").upper()
                cond_str = f" ({logic} : {' | '.join(r['conditions'])})" if r['conditions'] else ""
                line += f"\n    → Chemin '{r['label']}'{cond_str}"
            line += f"\n    → Chemin par défaut '{n.get('default_label','Défaut')}' (si aucune règle ne matche)"
        elif n["type"] == "actionCalls":
            line += f"\n    Apex: {n.get('action_name','')} ({n.get('action_type','')})"
            for inp in n.get('inputs', []):
                line += f"\n      input:  {inp}"
            for out in n.get('outputs', []):
                line += f"\n      output: {out}"
        elif n["type"] == "subflows":
            line += f"\n    → Appelle le flow : {n.get('flow_name','')}"
            for inp in n.get('inputs', []):
                line += f"\n      input: {inp}"
        elif n["type"] == "recordLookups":
            first = "premier enregistrement" if n.get('first_only') else "tous les enregistrements"
            line += f"\n    Objet: {n.get('object','')} ({first})"
            for f in n.get('filters', []):
                line += f"\n      filtre: {f}"
        elif n["type"] in ("recordCreates", "recordUpdates", "recordDeletes"):
            line += f"\n    Objet: {n.get('object','')}"
            for f in n.get('fields', []):
                line += f"\n      champ: {f}"
        elif n["type"] == "assignments":
            for item in n.get('items', []):
                line += f"\n      {item}"
        elif n["type"] == "loops":
            line += f"\n    Itère sur la collection : {n.get('collection','')}"
        elif n["type"] == "collectionProcessors":
            line += f"\n    Filtre la collection : {n.get('collection','')}"
            for c in n.get('conditions', []):
                line += f"\n      condition: {c}"
        nodes_summary.append(line)

    formulas_str = ""
    if formulas:
        for fx in formulas:
            formulas_str += f"  - `{fx['name']}` ({fx['data_type']}) : {fx['expression']}\n"
    else:
        formulas_str = "  (aucune)\n"

    reads_str  = "\n".join(f"  - {obj} . {f}" for obj, f in reads)  or "  (aucun)"
    writes_str = "\n".join(f"  - {obj} . {f}" for obj, f in writes) or "  (aucun)"
    deps_str   = ""
    if deps["subflows"]:
        deps_str += f"  Subflows appelés : {', '.join(deps['subflows'])}\n"
    if deps["apex"]:
        deps_str += f"  Classes Apex : {', '.join(deps['apex'])}\n"
    if not deps_str:
        deps_str = "  (aucune)\n"

    sched_str = ""
    if schedule:
        sched_str = f"  Fréquence: {schedule.get('frequency','')} | Heure: {schedule.get('start_time','')}"

    prompt = f"""Tu es expert Salesforce. Tu dois rédiger la fiche technique d'un Flow Salesforce en français, en Markdown.

## Données extraites du Flow

**Nom API** : {api_name}
**Label** : {label}
**Description** : {description or '(aucune)'}
**Application** : {app}
**Statut** : {status}

**Déclencheur** :
  - Type : {trigger_type}
  - Objet : {obj}
  - Événement : {rec_trigger}
  - Condition d'entrée : {filter_formula or ', '.join(filters_start) or '(aucune)'}
{sched_str}

**Nœuds du flow (dans l'ordre logique du XML)** :
{chr(10).join(nodes_summary)}

**Formules définies dans le flow** :
{formulas_str}
**Champs lus** :
{reads_str}

**Champs écrits** :
{writes_str}

**Dépendances** :
{deps_str}

## Format de sortie attendu

Génère UNIQUEMENT le contenu Markdown ci-dessous, sans balise de code, sans commentaire.

Règle de formatage obligatoire : tous les noms API (noms de variables, champs Salesforce, noms d'objets custom, noms de classes Apex, noms de flows, noms de Platform Events) doivent être écrits en `code` (backticks). Les noms d'objets standard Salesforce (Account, Opportunity, Contact…) sont aussi en `code`.

### `{api_name}`

**Label** : …

**Type** : … (ex: Record-Triggered Before Save)

**Objet** : …

**Déclencheur** : … (ex: Create & Update)

**Condition d'entrée** : … (résumé lisible de la formule ou des filtres)

**Statut** : …

**Application** : …

**Rôle** : Une phrase claire décrivant ce que fait ce flow du point de vue fonctionnel.

**Logique** :
Décris chaque étape dans l'ordre d'exécution, avec suffisamment de détail pour qu'un développeur puisse déboguer le flow sans l'ouvrir dans Salesforce.

Pour chaque étape, mentionne :
- Pour les **recordLookups** : l'objet requêté, TOUS les filtres appliqués (champ, opérateur, valeur), et si on récupère un ou plusieurs enregistrements
- Pour les **recordCreates / recordUpdates** : l'objet modifié et les champs affectés avec leur valeur source
- Pour les **assignments** : les variables affectées et leurs valeurs
- Pour les **decisions** : les conditions exactes de chaque branche, puis ce qui se passe sur chaque chemin
- Pour les **loops** : la collection itérée et ce qui est fait à chaque itération
- Pour les **collectionProcessors** : la collection filtrée et les conditions de filtre
- Pour les références à des formules (ex: `fxNomCompte`, `Formula_Name`) : expliciter l'expression complète de la formule et ce qu'elle calcule (les expressions sont fournies dans les données)

Format pour les décisions :
→ Si [condition exacte] : [ce qui se passe]
→ Sinon ([label du chemin par défaut]) : [ce qui se passe]

Ne pas résumer ni omettre d'étapes. Si le flow s'arrête sur un chemin sans rien faire, l'indiquer explicitement.

**Formules** : (section à inclure uniquement s'il y a des formules dans le flow)
| Nom | Type | Expression |
|-----|------|------------|
| `…` | … | `…` |

**Champs lus / écrits** :
| Sens | Objet | Champ |
|------|-------|-------|
| Lu | … | … |
| Écrit | … | … |

**Dépendances** : liste des subflows, classes Apex, Platform Events. Si aucune, écrire "Aucune."
"""
    return prompt


# ─── Point d'entrée ──────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_flow_doc.py <flow.flow-meta.xml>", file=sys.stderr)
        sys.exit(1)

    flow_path = Path(sys.argv[1])
    if not flow_path.exists():
        print(f"Fichier introuvable : {flow_path}", file=sys.stderr)
        sys.exit(1)

    tree = ET.parse(flow_path)
    root = tree.getroot()

    api_name    = flow_path.stem.replace(".flow-meta", "")
    label       = txt(root, "label") or api_name
    description = txt(root, "description")
    status      = txt(root, "status", "Unknown")
    app         = detect_app(api_name)

    start_info  = extract_start(root)
    nodes       = extract_nodes(root)
    formulas    = extract_formulas(root)
    reads, writes = extract_field_usage(root, nodes)
    deps        = extract_dependencies(nodes)

    prompt = build_prompt(api_name, label, description, app, start_info, nodes, reads, writes, deps, status, formulas)

    print(f"⏳  Appel à Claude pour {api_name}…", file=sys.stderr)
    result = subprocess.run(
        ["claude", "-p", prompt],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"Erreur Claude CLI :\n{result.stderr}", file=sys.stderr)
        sys.exit(1)

    content = result.stdout.strip()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_file = OUTPUT_DIR / f"{api_name}.md"
    out_file.write_text(content, encoding="utf-8")
    print(f"✅  Fiche générée : {out_file}", file=sys.stderr)
    print(str(out_file))


if __name__ == "__main__":
    main()