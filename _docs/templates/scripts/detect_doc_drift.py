#!/usr/bin/env python3
"""
Détecte ce qui a changé dans force-app/ depuis la dernière modification de la
documentation, et génère docs/DRIFT-DOCUMENTATION.md.

Référence de comparaison : le dernier commit ayant modifié un fichier sous docs/
(peu importe son message — pas de dépendance à une convention de nommage de commit).

Usage:
    python3 scripts/detect_doc_drift.py [--since <commit-ish>]

Couverture :
- Mode 2 (Flow, classe Apex, trigger, règle DLRS, bot Agentforce) : matching
  mécanique entre fichier source modifié et fiche docs/ existante -> 3 listes
  (à revalider, à créer, à supprimer/marquer obsolète).
- Mode 1 (doc fonctionnelle) : pas de correspondance 1-pour-1 fichier <-> doc,
  donc seulement un signal brut, regroupé par type de métadonnée, à trier
  manuellement en session pour juger si un document fonctionnel est impacté.
"""

import argparse
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
FORCE_APP = "force-app/main/default"
OUTPUT_FILE = REPO_ROOT / "docs" / "DRIFT-DOCUMENTATION.md"

# Dossier de métadonnées source -> dossier de fiches générées (Mode 2 uniquement).
MODE2_MAPPING = {
    "flows": "docs/flows",
    "classes": "docs/apex",
    "triggers": "docs/apex",
    "customMetadata": "docs/apex",  # règles DLRS
    "genAiPlannerBundles": "docs/agents",
    "botVersions": "docs/agents",
    "bots": "docs/agents",
}

# Libellés lisibles pour les types de métadonnée les plus pertinents en Mode 1.
# Tout dossier non listé ici utilise son nom brut comme libellé (fallback générique).
MODE1_LABELS = {
    "objects": "Objets et champs personnalisés",
    "layouts": "Page layouts",
    "flexipages": "Lightning pages",
    "permissionsets": "Permission sets",
    "permissionsetgroups": "Groupes de permission sets",
    "profiles": "Profils",
    "roles": "Rôles",
    "sharingRules": "Règles de partage",
    "validationRules": "Règles de validation",
    "workflows": "Workflow rules (legacy)",
    "approvalProcesses": "Processus d'approbation",
    "quickActions": "Quick actions",
    "reports": "Rapports",
    "dashboards": "Tableaux de bord",
    "duplicateRules": "Règles de doublons",
    "matchingRules": "Règles de correspondance",
    "namedCredentials": "Named credentials",
    "externalServiceRegistrations": "External services",
    "remoteSiteSettings": "Remote site settings",
    "communities": "Communautés / Experience Cloud",
    "applications": "Applications Salesforce",
    "tabs": "Onglets",
    "groups": "Groupes publics",
    "queues": "Files d'attente",
}


def run_git(*args):
    result = subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Erreur git {args}: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def find_last_doc_commit():
    """Dernier commit ayant modifié un fichier sous docs/, quel que soit son message."""
    out = run_git("log", "-1", "--format=%H", "--", "docs/")
    return out or None


def component_name_from_path(path: str) -> str:
    fname = Path(path).name
    fname = re.sub(r"\.flow-meta\.xml$", "", fname)
    fname = re.sub(r"\.cls(-meta\.xml)?$", "", fname)
    fname = re.sub(r"\.trigger(-meta\.xml)?$", "", fname)
    fname = re.sub(r"\.md-meta\.xml$", "", fname)
    fname = re.sub(r"\.botVersion-meta\.xml$", "", fname)
    fname = re.sub(r"\.genAiPlannerBundle-meta\.xml$", "", fname)
    fname = re.sub(r"\.bot-meta\.xml$", "", fname)
    return fname


def mode2_doc_dir(path: str):
    for src_dir, doc_dir in MODE2_MAPPING.items():
        if f"{FORCE_APP}/{src_dir}/" in path:
            return doc_dir
    return None


def mode1_type_label(path: str):
    rel = path.split(f"{FORCE_APP}/", 1)[-1]
    top_dir = rel.split("/", 1)[0]
    return MODE1_LABELS.get(top_dir, top_dir)


def find_existing_doc(doc_dir: str, component_name: str):
    d = REPO_ROOT / doc_dir
    if not d.exists():
        return None
    matches = list(d.glob(f"{component_name}.md"))
    return matches[0] if matches else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--since", help="Commit/tag de référence (défaut: dernier commit ayant touché docs/)")
    args = parser.parse_args()

    since = args.since or find_last_doc_commit()
    if not since:
        print("Aucun commit touchant docs/ trouvé, et --since non fourni.", file=sys.stderr)
        sys.exit(1)

    print(f"Comparaison entre {since[:8]} et HEAD…", file=sys.stderr)

    diff_output = run_git("diff", "--name-status", since, "HEAD", "--", FORCE_APP)
    if not diff_output:
        print("Aucun changement détecté dans force-app/ depuis la dernière modification de la documentation.")
        return

    mode2_to_review = []   # modifié, fiche existante -> à revalider
    mode2_to_create = []   # ajouté, pas de fiche -> à créer
    mode2_to_remove = []   # supprimé, fiche existante -> à supprimer/marquer obsolète
    mode1_by_type = defaultdict(list)

    for line in diff_output.splitlines():
        status, *path_parts = line.split("\t")
        # un rename a deux chemins (ancien, nouveau) ; on prend le nouveau s'il existe
        path = path_parts[-1]
        status_code = status[0]

        doc_dir = mode2_doc_dir(path)
        if doc_dir:
            name = component_name_from_path(path)
            existing_doc = find_existing_doc(doc_dir, name)
            entry = {"status": status_code, "path": path, "name": name, "doc": existing_doc}
            if status_code == "D":
                if existing_doc:
                    mode2_to_remove.append(entry)
            elif existing_doc:
                mode2_to_review.append(entry)
            else:
                mode2_to_create.append(entry)
        else:
            mode1_by_type[mode1_type_label(path)].append((status_code, path))

    status_label = {"M": "modifié", "A": "ajouté", "D": "supprimé"}

    lines = []
    lines.append("# Drift de documentation\n")
    lines.append(f"> Généré par `scripts/detect_doc_drift.py`. Comparaison entre `{since[:8]}` "
                  f"(dernier commit ayant modifié `docs/`) et `HEAD`.\n"
                  f"> Ce fichier est régénéré à chaque exécution — pas un historique cumulatif, "
                  f"un état \"à trier maintenant\".\n")

    lines.append("\n## Mode 2 — Composants techniques (Flow / Apex / Trigger / DLRS / Agentforce)\n")

    if mode2_to_review:
        lines.append("### Fiches à revalider (composant modifié, doc existante)\n")
        for e in mode2_to_review:
            lines.append(f"- [ ] `{e['name']}` — source modifiée : `{e['path']}` — fiche : `{e['doc'].relative_to(REPO_ROOT)}`")
        lines.append("")

    if mode2_to_create:
        lines.append("### Fiches à créer (nouveau composant, pas encore documenté)\n")
        for e in mode2_to_create:
            lines.append(f"- [ ] `{e['name']}` — source : `{e['path']}`")
        lines.append("")

    if mode2_to_remove:
        lines.append("### Fiches à supprimer ou marquer obsolètes (composant supprimé en prod)\n")
        for e in mode2_to_remove:
            lines.append(f"- [ ] `{e['name']}` — fiche : `{e['doc'].relative_to(REPO_ROOT)}` — source supprimée : `{e['path']}`")
        lines.append("")

    if not (mode2_to_review or mode2_to_create or mode2_to_remove):
        lines.append("Aucun changement détecté sur les composants couverts par le Mode 2.\n")

    lines.append("\n## Mode 1 — Doc fonctionnelle (signal brut, à trier manuellement)\n")
    lines.append("Pas de correspondance mécanique fichier <-> document ici. Pour chaque type "
                  "ci-dessous, juger en session si un document fonctionnel existant est impacté.\n")

    if mode1_by_type:
        for label in sorted(mode1_by_type):
            entries = mode1_by_type[label]
            lines.append(f"### {label} ({len(entries)})\n")
            for status_code, path in entries:
                lines.append(f"- [ ] {status_label.get(status_code, status_code)} — `{path}`")
            lines.append("")
    else:
        lines.append("Aucun changement détecté hors composants Mode 2.\n")

    report = "\n".join(lines)
    OUTPUT_FILE.write_text(report, encoding="utf-8")
    print(f"Écrit : {OUTPUT_FILE.relative_to(REPO_ROOT)}", file=sys.stderr)
    print(report)


if __name__ == "__main__":
    main()