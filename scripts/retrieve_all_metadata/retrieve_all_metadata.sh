#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 -a <org_alias> [-o <output_dir>]"
  echo ""
  echo "  -a  Alias de l'org SF (doit être déjà connecté via 'sf org login')"
  echo "  -o  Dossier de sortie (défaut: ./<alias>)"
  exit 1
}

ORG_ALIAS=""
OUTPUT_DIR=""

while getopts "a:o:" opt; do
  case $opt in
    a) ORG_ALIAS="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z "$ORG_ALIAS" ]] && usage

OUTPUT_DIR="${OUTPUT_DIR:-${ORG_ALIAS}}"
WORK_DIR="$(pwd)/$OUTPUT_DIR"

echo "--- Org         : $ORG_ALIAS"
echo "--- Output dir  : $WORK_DIR"
echo ""

# Vérification que l'org est bien connectée
if ! sf org display --target-org "$ORG_ALIAS" > /dev/null 2>&1; then
  echo "ERROR: Org '$ORG_ALIAS' introuvable. Lance d'abord : sf org login ..."
  exit 1
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Projet SF autonome pour que le retrieve écrive ici et non dans le repo parent
if [[ ! -f "sfdx-project.json" ]]; then
  cat > sfdx-project.json <<'EOF'
{
  "packageDirectories": [{ "path": "force-app", "default": true }],
  "sourceApiVersion": "67.0"
}
EOF
fi

[[ ! -d "force-app" ]] && mkdir force-app

# Génération du manifest complet depuis l'org
echo "--- Génération du package.xml depuis $ORG_ALIAS..."
sf project generate manifest --from-org "$ORG_ALIAS" --output-dir .

# Découpage du manifest en chunks < 10 000 membres
echo "--- Sanitisation du package.xml..."
python3 "$SCRIPT_DIR/sanitize.py" package.xml

echo "--- Packages générés :"
ls SanitizedPackages/
echo ""

# Retrieve en parallèle (5 workers)
echo "--- Retrieve de la métadonnée..."
ls SanitizedPackages | \
  xargs -I {} -P 5 \
  sf project retrieve start --manifest "SanitizedPackages/{}" --target-org "$ORG_ALIAS"

echo ""
echo "--- Backup terminé dans : $WORK_DIR/force-app"
