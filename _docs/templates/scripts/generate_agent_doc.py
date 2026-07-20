#!/usr/bin/env python3
"""
Génère la fiche Markdown d'un bot Agentforce à partir de son répertoire .bot-meta.xml.

Usage:
    python3 generate_agent_doc.py <chemin/vers/bots/NomBot/>

Sortie:
    docs/agents/<NomBot>.md
"""

import sys
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
OUTPUT_DIR = REPO_ROOT / "docs" / "agents"
FLOWS_DIR  = REPO_ROOT / "force-app" / "main" / "default" / "flows"

NS = "http://soap.sforce.com/2006/04/metadata"


def txt(el, path, default=""):
    node = el.find(f"{{{NS}}}{path}")
    return node.text.strip() if node is not None and node.text else default


def parse_bot(bot_dir: Path) -> dict:
    bot_file = next(bot_dir.glob("*.bot-meta.xml"))
    tree = ET.parse(bot_file)
    root = tree.getroot()
    return {
        "api_name":   bot_dir.name,
        "label":      txt(root, "label"),
        "type":       txt(root, "type"),
        "agent_type": txt(root, "agentType"),
        "description": txt(root, "description"),
        "log_private": txt(root, "logPrivateConversationData"),
        "session_timeout": txt(root, "sessionTimeout"),
    }


def parse_latest_version(bot_dir: Path) -> dict:
    """Retourne les données de la version la plus récente (numéro le plus élevé)."""
    versions = sorted(bot_dir.glob("v*.botVersion-meta.xml"),
                      key=lambda p: int(p.name.split(".")[0][1:]))
    if not versions:
        return {}

    latest = versions[-1]
    tree = ET.parse(latest)
    root = tree.getroot()

    role    = txt(root, "role")
    company = txt(root, "company")
    tone    = txt(root, "toneType")
    lang    = txt(root, "copilotPrimaryLanguage")
    version = latest.name.split(".")[0]

    planner_name = ""
    planner_el = root.find(f"{{{NS}}}conversationDefinitionPlanners/{{{NS}}}genAiPlannerName")
    if planner_el is not None and planner_el.text:
        planner_name = planner_el.text.strip()

    # Variables de conversation (injected in prompt)
    conv_vars = []
    for v in root.findall(f"{{{NS}}}conversationVariables"):
        name  = txt(v, "developerName")
        label = txt(v, "label")
        dtype = txt(v, "dataType")
        desc  = txt(v, "description")
        in_prompt = txt(v, "includeInPrompt")
        vis   = txt(v, "visibility")
        conv_vars.append({
            "name": name, "label": label, "type": dtype,
            "description": desc, "in_prompt": in_prompt, "visibility": vis
        })

    # Dialogs
    dialogs = []
    for d in root.findall(f"{{{NS}}}botDialogs"):
        dev_name = txt(d, "developerName")
        dlabel   = txt(d, "label")
        msgs = [txt(m, "message") for m in d.findall(f".//{{{NS}}}botMessages")]
        dialogs.append({"name": dev_name, "label": dlabel, "messages": msgs})

    return {
        "version": version,
        "role": role,
        "company": company,
        "tone": tone,
        "lang": lang,
        "planner": planner_name,
        "conv_vars": conv_vars,
        "dialogs": dialogs,
        "version_count": len(versions),
    }


def find_related_flows(api_name: str) -> list[str]:
    """Flows dont le nom commence par Agent_Action et qui sont liés à ce bot."""
    # Les flows Agent_Action sont globaux — on les liste tous
    flows = []
    for f in sorted(FLOWS_DIR.glob("Agent_Action*.flow-meta.xml")):
        flows.append(f.name.replace(".flow-meta.xml", ""))
    return flows


def build_prompt(bot: dict, version: dict, related_flows: list[str]) -> str:
    api_name = bot["api_name"]

    vars_str = ""
    for v in version.get("conv_vars", []):
        in_p = "oui" if v["in_prompt"] == "true" else "non"
        vars_str += f"  - `{v['name']}` ({v['type']}, inclus dans le prompt : {in_p}) : {v['description']}\n"
    if not vars_str:
        vars_str = "  (aucune)\n"

    dialogs_str = ""
    for d in version.get("dialogs", []):
        msgs = " / ".join(f'"{m}"' for m in d["messages"] if m)
        dialogs_str += f"  - `{d['name']}` ({d['label']}) : {msgs or '(aucun message)'}\n"

    flows_str = "\n".join(f"- `{f}`" for f in related_flows) if related_flows else "Aucun."

    return f"""Tu es expert Salesforce Agentforce. Tu dois rédiger la fiche technique d'un bot Agentforce en français, en Markdown.

## Données extraites

**Nom API** : {api_name}
**Label** : {bot['label']}
**Description** : {bot['description'] or '(aucune)'}
**Type d'agent** : {bot['agent_type']}
**Type de déploiement** : {bot['type']}
**Langue principale** : {version.get('lang', '')}
**Ton** : {version.get('tone', '')}
**Version documentée** : {version.get('version', 'v1')} (sur {version.get('version_count', 1)} version(s))
**Journalisation conversations privées** : {bot['log_private']}
**Planner GenAI** : {version.get('planner', '(non défini)')}

**Rôle (system prompt)** :
{version.get('role', '(non défini)')}

**Contexte entreprise (company prompt)** :
{version.get('company', '(non défini)')}

**Variables de conversation** :
{vars_str}
**Dialogs** :
{dialogs_str}
**Flows Action Agent associés** :
{flows_str}

## Format de sortie attendu

Génère UNIQUEMENT le contenu Markdown ci-dessous, sans balise de code englobante, sans commentaire avant ou après.

Règle de formatage : tous les noms API doivent être en `code` (backticks).

### `{api_name}`

**Label** : …

**Type** : … (ex: Agent Agentforce interne — `InternalCopilot`)

**Rôle** : Une phrase fonctionnelle décrivant ce que fait cet agent du point de vue utilisateur.

**System prompt** :
> Reproduire le contenu du champ `role` tel quel, dans un bloc citation Markdown.

**Contexte entreprise** :
> Reproduire le contenu du champ `company` tel quel, dans un bloc citation Markdown. (Omettre cette section si vide.)

**Configuration** :
| Paramètre | Valeur |
|-----------|--------|
| Langue principale | … |
| Ton | … |
| Version active | … |
| Journalisation des conversations | … |
| Planner GenAI | … |

**Variables de conversation** :
Liste les variables injectées dans le contexte de l'agent, avec leur rôle. Distinguer celles incluses dans le prompt (`includeInPrompt = true`) de celles qui ne le sont pas.

| Variable | Type | Dans le prompt | Rôle |
|----------|------|----------------|------|
| `…` | … | Oui/Non | … |

**Dialogs** :
Liste les dialogs définis (scénarios de conversation prédéfinis). Pour chaque dialog, indiquer son nom, son rôle et le message affiché.

| Dialog | Rôle | Message |
|--------|------|---------|
| `…` | … | "…" |

**Flows Action Agent** : (section à inclure uniquement si des flows sont listés)
Liste des flows invocables par l'agent comme actions. Pour chaque flow, une ligne de description.

**Dépendances** : profils nécessaires, permission sets, objets Salesforce consultés. Indiquer "À compléter" si non déterminable depuis les métadonnées.
"""


def call_claude(prompt: str, name: str) -> str:
    print(f"⏳  Appel à Claude pour {name}…", file=sys.stderr)
    result = subprocess.run(["claude", "-p", prompt], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Erreur Claude CLI :\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_agent_doc.py <bots/NomBot/>", file=sys.stderr)
        sys.exit(1)

    bot_dir = Path(sys.argv[1])
    if not bot_dir.is_dir():
        print(f"Répertoire introuvable : {bot_dir}", file=sys.stderr)
        sys.exit(1)

    bot     = parse_bot(bot_dir)
    version = parse_latest_version(bot_dir)
    flows   = find_related_flows(bot["api_name"])

    prompt  = build_prompt(bot, version, flows)
    content = call_claude(prompt, bot["api_name"])

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_file = OUTPUT_DIR / f"{bot['api_name']}.md"
    out_file.write_text(content, encoding="utf-8")
    print(f"✅  Fiche générée : {out_file}", file=sys.stderr)
    print(str(out_file))


if __name__ == "__main__":
    main()