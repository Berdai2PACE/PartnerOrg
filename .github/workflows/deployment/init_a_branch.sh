
#!/bin/bash
# 0. Check if gh is logged in
echo "Checking GitHub CLI authentication..."
if ! gh api user --jq '.login' > /dev/null 2>&1; then
    echo "❌ Error: You are not logged into GitHub CLI."
    gh auth login
fi
echo "✅ Authenticated."
# 1. Ask for the branch name
read -p "Enter the branch name: " inputName
#!/bin/bash

# 1. Fetch existing repository variables and store in a list
# We use --json name to get a clean list of keys
EXISTING_VARS=$(gh variable list --json name --jq '.[].name')

# Function to check and set variable
sync_git_to_gh() {
    local var_name=$1
    local git_config_key=$2

    # Check if the variable name exists in our list
    if echo "$EXISTING_VARS" | grep -q "^$var_name$"; then
        echo "✅ GitHub variable '$var_name' is already set."
    else
        echo "⚠️  '$var_name' not found. Fetching from local git config..."
        
        # Get value from local git config
        local val=$(git config --get "$git_config_key")

        if [ -z "$val" ]; then
            echo "❌ Error: Could not find '$git_config_key' in your local git config."
        else
            # Set the variable in GitHub
            gh variable set "$var_name" --body "$val"
            echo "🚀 Successfully set GitHub variable '$var_name' to '$val'."
        fi
    fi
}

# 2. Execute for both fields
sync_git_to_gh "BACKUP_USEREMAIL" "user.email"
sync_git_to_gh "BACKUP_USERNAME" "user.name"
# 2. Convert to ALL CAPS
# Note: Using ^^ is a bash 4+ feature for uppercase conversion
branchName=$(echo "$inputName" | tr '[:upper:]' '[:lower:]')

# Define the full branch and tag names
releaseBranch="release/$branchName"
backupBranch="backup/$branchName"
tagName="deploy$branchName"

echo "Targeting branch: $releaseBranch"
echo "Targeting tag: $tagName"

# 3. Check if the release branch exists on remote
# 'gh repo view' or 'gh browse' aren't as precise for this, 
# so we use git ls-remote via gh's authenticated context.
if gh api repos/:owner/:repo/branches/$releaseBranch > /dev/null 2>&1; then
    echo "Branch '$releaseBranch' already exists."
else
    echo "Branch '$releaseBranch' not found. Creating it from the default branch..."
    
    # Get the default branch name (usually 'main' or 'master')
    defaultBranch=$(gh repo view --json defaultBranchRef --template '{{.defaultBranchRef.name}}')
    
    # Create the branch via API to avoid local checkout overhead
    # We fetch the SHA of the default branch first
    sha=$(gh api repos/:owner/:repo/git/ref/heads/$defaultBranch --template '{{.object.sha}}')
    
    gh api repos/:owner/:repo/git/refs \
      -f ref="refs/heads/$releaseBranch" \
      -f sha="$sha" > /dev/null
      
    echo "Created branch '$releaseBranch' at $sha."

fi

if gh api repos/:owner/:repo/branches/$backupBranch > /dev/null 2>&1; then
    echo "Branch '$backupBranch' already exists."
else
    echo "Branch '$backupBranch' not found. Creating it from the default branch..."
    
    # Get the default branch name (usually 'main' or 'master')
    defaultBranch=$(gh repo view --json defaultBranchRef --template '{{.defaultBranchRef.name}}')
    
    # Create the branch via API to avoid local checkout overhead
    # We fetch the SHA of the default branch first
    sha=$(gh api repos/:owner/:repo/git/ref/heads/$defaultBranch --template '{{.object.sha}}')
    
    gh api repos/:owner/:repo/git/refs \
      -f ref="refs/heads/$backupBranch" \
      -f sha="$sha" > /dev/null
      
    echo "Created branch '$backupBranch' at $sha."

fi

# 4. Force the creation of the tag
# We'll point the tag to the latest commit on our release branch
targetSha=$(gh api repos/:owner/:repo/git/ref/heads/$releaseBranch --template '{{.object.sha}}')

echo "Updating tag '$tagName' to point to $targetSha..."

# In Git, you can't easily "force update" a tag via a single POST 
# if it exists, so we delete and recreate for a clean 'force' behavior.
gh api -X DELETE repos/:owner/:repo/git/refs/tags/$tagName > /dev/null 2>&1

gh api repos/:owner/:repo/git/refs \
  -f ref="refs/tags/$tagName" \
  -f sha="$targetSha" > /dev/null

echo "Success: Tag '$tagName' is now set."

# 5.Check/Initialize the Environment
# We check if the environment exists by trying to 'get' it
if gh api repos/:owner/:repo/environments/$branchName > /dev/null 2>&1; then
    echo "Environment '$branchName' already exists."
else
    echo "Environment '$branchName' not found. Initializing..."
    # Create the environment via PUT request
    gh api -X PUT repos/:owner/:repo/environments/$branchName > /dev/null
    echo "Environment '$branchName' created successfully."
fi
# Define Environment Name (using your all-caps branchName)
echo "--- Configuring Environment: $branchName ---"

# 6. Set Environment Variable: BACKUP_MESSAGE
# Variable bodies can be passed directly via the --body flag
backupMsg="Commit metadata from $branchName"

gh variable set BACKUP_MESSAGE \
  --env "$branchName" \
  --body "$backupMsg"
gh variable set BRANCH_NAME \
  --env "$branchName" \
  --body "$backupBranch"

echo "✅ Variable BACKUP_MESSAGE set for environment '$branchName'."

# 7. Set Environment Secret: sfdxAuthURL
# We use 'read -s' so the secret isn't visible on your screen while typing
read -sp "Enter the sfdxAuthURL for $branchName: " sfdxInput
echo "" # Clean line break after hidden input

# We pipe the secret into 'gh secret set' for better security 
# than passing it as a command-line argument.
echo "$sfdxInput" | gh secret set sfdxAuthURL --env "$branchName"

echo "✅ Secret sfdxAuthURL set for environment '$branchName'."
# 6. Optional Force Deploy Setup with Validation Loop
while true; do
    read -p "Setup code check on this branch? (Y/N): " choice
    case "$choice" in 
        ([yY][eE][sS]|[yY])
            echo "Configuring Check code..."
            
            # Set boolean variable to true
            gh variable set CHECKCODE --env "$branchName" --body "true"
            # 1. Fetch existing repository variables and store in a list
            # We use --json name to get a clean list of keys
            EXISTING_VARS=$(gh secrets list --json name --jq '.[].name')
            if echo "$EXISTING_VARS" | grep -q "^PAT_PR$"; then
                echo "✅ GitHub variable 'PAT_PR' is already set."
            else

                # Set PAT_PR secret
                read -sp "Enter PAT_PR (a PAT with read on content and write on PR): " patSecret
                echo ""
                echo "$patSecret" | gh secret set PAT_PR
            fi       
            echo "✅ Check code configured for $branchName."
            break # Exit the loop
            ;;
            
        ([nN][oO]|[nN])
            echo "Setting CHECKCODE to false..."
            gh variable set CHECKCODE --env "$branchName" --body "false"
            echo "⏭️ Skippingcheck code setup."
            break # Exit the loop
            ;;
            
        (*)
            echo "❌ Invalid input. Please type 'Y' for Yes or 'N' for No."
            # No 'break' here, so the loop repeats
            ;;
    esac
done
# 7. Optional Force Deploy Setup with Validation Loop
while true; do
    read -p "Setup deployment to another org? (Y/N): " choice
    case "$choice" in 
        ([yY][eE][sS]|[yY])
            echo "Configuring Force Deploy..."
            
            # Set boolean variable to true
            gh variable set FORCEDEPLOY --env "$branchName" --body "true"
            
            # Set the second secret
            read -sp "Enter SFDXAUTHURL_FORCEDEPLOY: " forceSecret
            echo ""
            echo "$forceSecret" | gh secret set SFDXAUTHURL_FORCEDEPLOY --env "$branchName"
            
            echo "✅ Force Deploy configured for $branchName."
            break # Exit the loop
            ;;
            
        ([nN][oO]|[nN])
            echo "Setting FORCEDEPLOY to false..."
            gh variable set FORCEDEPLOY --env "$branchName" --body "false"
            echo "⏭️ Skipping Force Deploy setup."
            break # Exit the loop
            ;;
            
        (*)
            echo "❌ Invalid input. Please type 'Y' for Yes or 'N' for No."
            # No 'break' here, so the loop repeats
            ;;
    esac
done

echo "--- All settings applied to environment '$branchName' ---"