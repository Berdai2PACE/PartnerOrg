#!/bin/bash

# RCA Management Script
# Usage: ./rca_manage.sh --mode <dry-run-prep|deploy-prep|deploy-execute> --source-dir <path>

MODE=""
SOURCE_DIR=""
ORG_ALIAS=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --mode) MODE="$2"; shift ;;
        --source-dir) SOURCE_DIR="$2"; shift ;;
        --org) ORG_ALIAS="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$MODE" ] || [ -z "$SOURCE_DIR" ]; then
    echo "Usage: ./rca_manage.sh --mode <dry-run-prep|deploy-prep|deploy-execute> --source-dir <path>"
    exit 1
fi

echo "RCA Manager: Starting in $MODE mode for directory $SOURCE_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory $SOURCE_DIR does not exist. Exiting."
    exit 0
fi

# Define paths
# Use absolute path for staging to avoid issues with pushd
TEMP_RCA_DIR="$(pwd)/${SOURCE_DIR}_rca_staging"
mkdir -p "$TEMP_RCA_DIR"

# Helper function to find and move files
find_and_move() {
    local pattern=$1
    local type_name=$2
    
    mkdir -p "$TEMP_RCA_DIR"

    # We use a while loop to handle files safely
    # cd to SOURCE_DIR to get relative paths
    pushd "$SOURCE_DIR" > /dev/null || return
    
    # Check if any files exist first to avoid errors
    local count=$(find . -name "$pattern" | wc -l)
    if [ "$count" -eq 0 ]; then
        popd > /dev/null
        return
    fi
    
    find . -name "$pattern" -print0 | while IFS= read -r -d '' file; do
        local dir=$(dirname "$file")
        local dest_dir="$TEMP_RCA_DIR/$dir"
        mkdir -p "$dest_dir"
        
        # Move file using absolute path for destination to be safe or relative from here?
        # $file is relative to the current dir (SOURCE_DIR)
        mv "$file" "$dest_dir/"
    done
    
    popd > /dev/null
}

if [ "$MODE" == "dry-run-prep" ]; then
    echo "Dry-Run Prep: Isolating Expression Set and Pricing Recipe to SKIP them."
    # Move Expression Set and Pricing Recipe OUT of SOURCE_DIR into TEMP_RCA_DIR (which will be ignored/deleted)
    
    # Pricing Recipe
    find_and_move "*.pricingRecipe-meta.xml" "PricingRecipe"
    # Expression Set
    find_and_move "*.expressionSetDefinition-meta.xml" "ExpressionSet"
    # Expression Set Version
    find_and_move "*.expressionSetVersion-meta.xml" "ExpressionSetVersion"
    
    echo "Expression Sets and Pricing Recipes moved to $TEMP_RCA_DIR. They will NOT be deployed in this dry run."
    # Context Definition and Decision Table stay in SOURCE_DIR and will be validated.
    exit 0
fi

if [ "$MODE" == "deploy-prep" ]; then
    echo "Deploy Prep: Moving ALL RCA components out of SOURCE_DIR to Staging."
    
    # Move ALL RCA types
    find_and_move "*.contextDefinition-meta.xml" "ContextDefinition"
    find_and_move "*.decisionTable-meta.xml" "DecisionTable"
    find_and_move "*.expressionSetDefinition-meta.xml" "ExpressionSet"
    find_and_move "*.expressionSetVersion-meta.xml" "ExpressionSetVersion"
    find_and_move "*.pricingRecipe-meta.xml" "PricingRecipe"
    
    echo "All RCA components moved to $TEMP_RCA_DIR."
    echo "Main deployment can now proceed with non-RCA files."
    exit 0
fi

if [ "$MODE" == "deploy-execute" ]; then
    echo "Deploy Execute: Deactivating and Deploying RCA components from Staging."
    
    if [ ! -d "$TEMP_RCA_DIR" ]; then
        echo "No RCA staging directory found ($TEMP_RCA_DIR). Nothing to deploy."
        exit 0
    fi

    # Check if there are actually files in TEMP_RCA_DIR
    FILE_COUNT=$(find "$TEMP_RCA_DIR" -type f | wc -l)
    if [ "$FILE_COUNT" -eq 0 ]; then
        echo "Staging directory is empty. No RCA components to deploy."
        rm -rf "$TEMP_RCA_DIR"
        exit 0
    fi

    # 1. Ordered Deployment
    deploy_files() {
        local type_name=$1
        local pattern=$2
        # Find files of this type in TEMP_RCA_DIR
        local files=$(find "$TEMP_RCA_DIR" -name "$pattern")
        
        if [ ! -z "$files" ]; then
            echo "Deploying $type_name..."
            # Using 'sf project deploy start --source-dir' with the staging directory works 
            # IF we point to the specific files we want to deploy NOW.
            
            # We construct a list of file paths.
            local file_list=$(echo "$files" | tr '\n' ' ')
            if [ -n "$ORG_ALIAS" ]; then
                sf project deploy start --ignore-conflicts --source-dir $file_list --target-org "$ORG_ALIAS"
            else
                sf project deploy start --ignore-conflicts --source-dir $file_list
            fi
        else
            echo "No $type_name to deploy."
        fi
    }

    # Order: Context -> Decision Table -> Pricing Recipe -> Expression Set Definition -> Expression Set Version
    deploy_files "Context Definitions" "*.contextDefinition-meta.xml"
    deploy_files "Decision Tables" "*.decisionTable-meta.xml"
    deploy_files "Pricing Recipes" "*.pricingRecipe-meta.xml"
    deploy_files "Expression Set Definitions" "*.expressionSetDefinition-meta.xml"
    deploy_files "Expression Set Versions" "*.expressionSetVersion-meta.xml"

    # Cleanup
    rm -rf "$TEMP_RCA_DIR"
    echo "RCA Deployment Complete."
fi
