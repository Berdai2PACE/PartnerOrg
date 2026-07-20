#!/bin/bash
# ---
# Retrieves a custom field and all its metadata dependencies.
# Runs against the default configured Salesforce CLI org.
# Handles both Standard and Custom objects.
# Correctly resolves Layout and Flow names.
#
# Requires:
#   - Salesforce CLI (sf)
#   - jq (JSON processor)
# ---

# === CONFIGURATION ===
# ❗ Set the full API name of the field you want to retrieve
FULL_FIELD_NAME="Visit_report__c.Current_Discussion__c"
# =====================


# 1. Parse the field name into object and field components
OBJECT_NAME=$(echo $FULL_FIELD_NAME | cut -d. -f1)
# Gets the field name without the __c, which is the DeveloperName
FIELD_NAME=$(echo $FULL_FIELD_NAME | cut -d. -f2 | sed 's/__c$//')

echo "-----------------------------------------------------"
echo "🔍 Retrieving dependencies for: $FULL_FIELD_NAME"
echo "(Using default org)"
echo "-----------------------------------------------------"

# 2. STEP 1: Get the Field ID
# This is now a multi-step process to correctly find the TableEnumOrId

echo "Step 1a: Resolving Object ID (TableEnumOrId)..."
TABLE_ID=""

# Check if it's a custom object (ends in __c)
if [[ "$OBJECT_NAME" == *__c ]]; then
    # It's a custom object. We need its ID.
    # Strip __c to get DeveloperName for CustomObject query
    OBJECT_DEV_NAME=$(echo $OBJECT_NAME | sed 's/__c$//')
    echo "Custom object detected. Fetching ID for $OBJECT_DEV_NAME..."
    
    OBJECT_ID_QUERY="SELECT Id FROM CustomObject WHERE DeveloperName = '$OBJECT_DEV_NAME'"
    TABLE_ID=$(sf data query --use-tooling-api --query "$OBJECT_ID_QUERY" --json | jq -r ".result.records[0].Id")

    if [ -z "$TABLE_ID" ] || [ "$TABLE_ID" == "null" ]; then
        echo "❌ ERROR: Could not find CustomObject ID for $OBJECT_DEV_NAME."
        echo "Please check the object name and your default org."
        exit 1
    fi
    echo "✅ Object ID: $TABLE_ID"
else
    # It's a standard object. The name is the ID.
    echo "Standard object detected."
    TABLE_ID="$OBJECT_NAME"
    echo "✅ Object Name: $TABLE_ID"
fi
echo "---"

echo "Step 1b: Fetching Field ID using TableEnumOrId..."
FIELD_ID_QUERY="SELECT Id FROM CustomField WHERE DeveloperName = '$FIELD_NAME' AND TableEnumOrId = '$TABLE_ID'"

FIELD_ID=$(sf data query --use-tooling-api --query "$FIELD_ID_QUERY" --json | jq -r ".result.records[0].Id")

if [ -z "$FIELD_ID" ] || [ "$FIELD_ID" == "null" ]; then
    echo "❌ ERROR: Could not find Field ID for $FULL_FIELD_NAME."
    echo "Query: $FIELD_ID_QUERY"
    exit 1
fi
echo "✅ Success! Field ID: $FIELD_ID"
echo "---"


# 3. STEP 2: Find Dependencies
echo "Step 2: Querying for metadata dependencies..."
# This query is correct. For Layouts/Flows, MetadataComponentName will be the ID.
DEP_QUERY="SELECT MetadataComponentType, MetadataComponentName,MetadataComponentId \
           FROM MetadataComponentDependency \
           WHERE RefMetadataComponentId = '$FIELD_ID' AND RefMetadataComponentType = 'CustomField' \
           ORDER BY MetadataComponentType, MetadataComponentName"

DEP_RESULTS_JSON=$(sf data query --use-tooling-api --query "$DEP_QUERY" --json)
RECORDS_FOUND=$(echo "$DEP_RESULTS_JSON" | jq -r '.result.records | length')

echo "✅ Found $RECORDS_FOUND dependencies."
echo "---"

# 4. STEP 3: Build and Run Retrieve Command
echo "Step 3: Building and executing 'sf project retrieve start'..."

# We use a bash array to safely build the list of metadata arguments
METADATA_ARGS=()

# First, add the field itself to the retrieve list
METADATA_ARGS+=("-m" "CustomField:$FULL_FIELD_NAME")

# Loop through the JSON results and add each dependency to the array
# We use jq -c to get compact JSON for each record
while IFS= read -r record_json; do
    # Parse the type and name from the JSON line
    TYPE=$(echo "$record_json" | jq -r '.MetadataComponentType')
    NAME=$(echo "$record_json" | jq -r '.MetadataComponentName')
    METADATA_ID=$(echo "$record_json" | jq -r '.MetadataComponentId')

    if [ "$TYPE" == "Layout" ]; then
        # ❗ This is a Layout. NAME is an ID. We need to query for its "full name".
        echo "  > Resolving Layout ID: $NAME"
        LAYOUT_QUERY="SELECT FullName FROM Layout WHERE Id = '$METADATA_ID'"
        LAYOUT_FULL_NAME=$(sf data query --use-tooling-api --query "$LAYOUT_QUERY" --json | jq -r ".result.records[0].FullName")

        if [ -n "$LAYOUT_FULL_NAME" ] && [ "$LAYOUT_FULL_NAME" != "null" ]; then
            METADATA_ARGS+=("-m" "Layout:$LAYOUT_FULL_NAME")
            echo "    > Resolved to: Layout:$LAYOUT_FULL_NAME"
        else
            echo "    ⚠️ WARNING: Could not resolve Layout name for ID $NAME. Skipping."
        fi
        
    elif [ "$TYPE" == "Flow" ]; then
        # ❗ This is a Flow. NAME is an ID. We need to query for its FullName and strip the version.
        echo "  > Resolving Flow ID: $NAME"
        FLOW_QUERY="SELECT FullName FROM Flow WHERE Id = '$METADATA_ID'"
        FLOW_FULL_NAME_WITH_VERSION=$(sf data query --use-tooling-api --query "$FLOW_QUERY" --json | jq -r ".result.records[0].FullName")
        
        if [ -n "$FLOW_FULL_NAME_WITH_VERSION" ] && [ "$FLOW_FULL_NAME_WITH_VERSION" != "null" ]; then
            # Strip the version number (e.g., "-3") from the end
            FLOW_CLEAN_NAME=$(echo $FLOW_FULL_NAME_WITH_VERSION | cut -d- -f1)
            METADATA_ARGS+=("-m" "Flow:$FLOW_CLEAN_NAME")
            echo "    > Resolved to: Flow:$FLOW_CLEAN_NAME (from $FLOW_FULL_NAME_WITH_VERSION)"
        else
            echo "    ⚠️ WARNING: Could not resolve Flow name for ID $NAME. Skipping."
        fi
        
    else
        # This is a normal component. Add it directly.
        METADATA_ARGS+=("-m" "$TYPE:$NAME")
    fi
done < <(echo "$DEP_RESULTS_JSON" | jq -c '.result.records[]')


# List the components being retrieved
echo ""
echo "Components to retrieve:"
printf "  - %s\n" "${METADATA_ARGS[@]}" | sed 's/-m //g'
echo "---"

# Execute the final command
sf project retrieve start "${METADATA_ARGS[@]}"

echo "-----------------------------------------------------"
echo "✅ Retrieve command executed."
echo "-----------------------------------------------------"