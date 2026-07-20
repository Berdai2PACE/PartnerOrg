#!/bin/bash
set -e

# Define paths
OBJECTS_DIR="force-app/main/default/objects"
R_SCRIPT="scripts/PermissionSetHandleFields/cleanPermission.r"
PERM_SETS_DIR="force-app/main/default/permissionsets"
CONF_FILE="scripts/conf.json"

echo "Discarding changes in $OBJECTS_DIR ..."
if [ -d "$OBJECTS_DIR" ]; then
    git restore "$OBJECTS_DIR"
    git clean -fd "$OBJECTS_DIR"
else
    echo "Warning: $OBJECTS_DIR does not exist."
fi

# Detect targets from conf.json using Node.js for reliable JSON parsing
echo "Reading configuration..."
TARGETS_OUTPUT=$(node -e "
  try {
    const fs = require('fs');
    if (!fs.existsSync('$CONF_FILE')) { console.log('ALL'); process.exit(0); }
    const conf = require('./$CONF_FILE');
    const t = conf.targets;
    if (!t || t.length === 0 || t.includes('ALL')) {
      console.log('ALL');
    } else {
      // Normalize names: strip .xml or .permissionset-meta.xml if present
      const names = t.map(x => x.replace(/\.permissionset-meta\.xml$/, '').replace(/\.xml$/, ''));
      console.log(names.join(' '));
    }
  } catch (e) { console.error(e); console.log('ALL'); }
")

if [ "$TARGETS_OUTPUT" == "ALL" ]; then
    echo "🌍 Mode: ALL files."
    echo "Retrieving ALL Permission Sets..."
    sf project retrieve start -m PermissionSet -c
    
    echo "Running R cleaning script..."
    if [ -f "$R_SCRIPT" ]; then
        Rscript "$R_SCRIPT"
    else
        echo "Error: R script not found at $R_SCRIPT"
        exit 1
    fi
    
    echo "Staging ALL Permission Sets..."
    git add "$PERM_SETS_DIR"
else
    echo "🎯 Mode: Specific files: $TARGETS_OUTPUT"
    
    # Construct arrays for arguments
    SF_ARGS=()
    GIT_ADD_ARGS=()
    
    # Read space-separated targets into array
    # set -f disables globbing so * inside names wouldn't expand, though unlikely here
    set -f
    IFS=' ' read -r -a TARGET_ARRAY <<< "$TARGETS_OUTPUT"
    set +f
    
    for perm in "${TARGET_ARRAY[@]}"; do
        SF_ARGS+=("-m" "PermissionSet:$perm")
        GIT_ADD_ARGS+=("$PERM_SETS_DIR/$perm.permissionset-meta.xml")
    done
    
    echo "Retrieving specific Permission Sets..."
    sf project retrieve start "${SF_ARGS[@]}" -c
    
    echo "Running R cleaning script..."
    if [ -f "$R_SCRIPT" ]; then
        Rscript "$R_SCRIPT"
    else
        echo "Error: R script not found at $R_SCRIPT"
        exit 1
    fi
    
    echo "Staging specific Permission Sets..."
    if [ ${#GIT_ADD_ARGS[@]} -gt 0 ]; then
        git add "${GIT_ADD_ARGS[@]}"
    else
        echo "Warning: No files to stage."
    fi
fi

echo "✅ Automation complete! Permission sets have been handled."
