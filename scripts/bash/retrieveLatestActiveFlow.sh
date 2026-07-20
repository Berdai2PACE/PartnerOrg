#!/bin/zsh

# --- Configuration ---
# 👉 Set this to your target org's alias

# Path to your flows directory
FLOW_DIR="force-app/main/default/flows"
# ---------------------

# 1. Find local flow files and get their API names
echo "🔍 Finding flows in '$FLOW_DIR'..."
flow_api_names=()
for flow_file in "$FLOW_DIR"/*.flow-meta.xml; do
  
  # Check if any files were found
  if [ ! -e "$flow_file" ]; then
    echo "🚫 Error: No .flow-meta.xml files found in '$FLOW_DIR'."
    echo "Please run this script from your Salesforce project's root directory."
    exit 1
  fi
  
  # Get filename without path
  filename=$(basename "$flow_file")
  # Get API name by removing the extension
  api_name="${filename%.flow-meta.xml}"
  
  # Add to array, single-quoted for SOQL
  flow_api_names+=("'$api_name'")
done

# Join the array with commas to create the 'IN' clause
in_clause=$(IFS=,; echo "${flow_api_names[*]}")

if [ -z "$in_clause" ]; then
  echo "No flows found to query."
  exit 0
fi

echo "Found local flows: ${in_clause}"

# 2. Build and execute the SOQL query
soql_query="SELECT ApiName, VersionNumber FROM FlowDefinitionView WHERE IsActive = true AND ApiName IN ($in_clause)"

echo "🚀 Querying org for active versions..."
echo "SOQL: $soql_query"

# Execute query, requesting JSON output for parsing
query_result_json=$(sf data query --query "$soql_query" --json)

# Check if the query command failed
if [ $? -ne 0 ]; then
    echo "🚫 Error executing SOQL query."
    echo "Check that  is correct and you are authenticated."
    echo "$query_result_json" # Print error details from sf
    exit 1
fi

# 3. Parse JSON and format for the retrieve command
echo "🔄 Parsing query results..."

# Use 'jq' to parse the JSON and format as "ApiName-VersionNumber"
# Then use 'paste -sd,' to join all lines with a comma
retrieve_manifest_flags=$(echo "$query_result_json" | \
                            jq -r '.result.records[] | "-m \"Flow:\(.ApiName)-\(.VersionNumber)\""' | \
                            paste -sd' ' -)

if [ -z "$retrieve_manifest_flags" ]; then
  echo "⚠️ No *active* versions were found in the org for the local flows."
  exit 0
fi

# 4. Build and execute the final retrieve command
final_command="sf project retrieve start $retrieve_manifest_flags "

echo "---"
echo "✅ Success! Your retrieve command is ready:"
echo ""
echo "$final_command"
eval $final_command

# 5. Rename retrieved files to strip version number suffix (e.g. MyFlow-3.flow-meta.xml → MyFlow.flow-meta.xml)
echo "🔄 Cleaning up version numbers from flow filenames..."
renamed_count=0
for versioned_file in "$FLOW_DIR"/*-[0-9]*.flow-meta.xml; do
  [ -e "$versioned_file" ] || continue
  filename=$(basename "$versioned_file")
  clean_name=$(echo "$filename" | sed 's/-[0-9][0-9]*\.flow-meta\.xml$/.flow-meta.xml/')
  if [ "$filename" != "$clean_name" ]; then
    mv -f "$versioned_file" "$FLOW_DIR/$clean_name"
    echo "  Renamed: $filename → $clean_name"
    renamed_count=$((renamed_count + 1))
  fi
done
[ $renamed_count -gt 0 ] && echo "✅ Renamed $renamed_count flow file(s)." || echo "ℹ️ No version-suffixed files to rename."

echo "---"
echo "🎉 Retrieve complete."