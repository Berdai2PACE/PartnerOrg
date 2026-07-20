#!/bin/bash

# RCA Local Test Utility
# Simulates the GitHub Action "Simulate Deployment" (Dry Run) logic locally.

TARGET_BRANCH=${1:-uat}
ORG_ALIAS=$2

if [ -z "$ORG_ALIAS" ]; then
    echo ">>> No org alias provided. Using default authenticated org."
else
    echo ">>> Target Org:    $ORG_ALIAS"
fi

# 1. Clean up
echo ">>> Cleaning up..."
rm -rf changed-sources/
mkdir changed-sources/

# 2. Generate Delta
echo ">>> Generating Delta using sf-git-delta..."
sf sgd source delta --to HEAD --from "$TARGET_BRANCH" --output changed-sources --generate-delta

if [ ! -d "changed-sources/force-app" ]; then
    echo ">>> No changes detected in force-app. Skipping."
    exit 0
fi

# 3. RCA Dry Run Prep (Exclude problematic types)
echo ">>> preparing RCA Dry Run (Excluding Expression Sets & Pricing Recipes)..."
chmod +x scripts/bash/rca_manage.sh
if [ -n "$ORG_ALIAS" ]; then
    ./scripts/bash/rca_manage.sh --mode dry-run-prep --source-dir changed-sources/force-app --org "$ORG_ALIAS"
    echo ">>> Executing sf project deploy dry-run on $ORG_ALIAS..."
    sf project deploy start --dry-run --ignore-conflicts --source-dir changed-sources/force-app --target-org "$ORG_ALIAS"
else
    ./scripts/bash/rca_manage.sh --mode dry-run-prep --source-dir changed-sources/force-app
    echo ">>> Executing sf project deploy dry-run on default org..."
    sf project deploy start --dry-run --ignore-conflicts --source-dir changed-sources/force-app
fi

echo ">>> Local Test Complete!"
