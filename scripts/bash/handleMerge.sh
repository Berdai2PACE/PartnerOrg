
HEAD_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD);
ORG_NAME=$(echo $1 | cut -d'/' -f2);

if [ -z "$HEAD_BRANCH_NAME" ]; then
  echo "❌ HEAD_BRANCH_NAME is empty. Aborting."
  exit 1
fi

echo 'Pushing changes...';
git push 
git pull origin $1
git checkout $HEAD_BRANCH_NAME

echo 'Checking if branches can be merged...';
MERGE_TREE_OUTPUT=$(git merge-tree --write-tree HEAD $1 2>&1); 
MERGE_EXIT_CODE=$?; 

if [ $MERGE_EXIT_CODE -eq 0 ]; then 
    
    echo '✅ SUCCESS: Branches can be merged cleanly.'; 

    echo 'Attempting to create GitHub Pull Request...'; 
    if ! command -v gh &> /dev/null; 
        then echo '⚠️ WARNING: GitHub CLI \"gh\" not found. Cannot create PR.'; 
        echo 'Please install it to automate PR creation: https://cli.github.com/'; 
        exit 0; 
    fi; 


    echo 'Creating Pull Request... (This may prompt you to push your branch)'; 
    ORG_NAME=$(echo \"$1\" | cut -d'/' -f2); 
    REMOTE_HEAD_BRANCH=\"release/$ORG_NAME\"; 

    echo \"Using remote head branch: $REMOTE_HEAD_BRANCH; 
    gh pr create --base $1 --head $HEAD_BRANCH_NAME --title \"$HEAD_BRANCH_NAME\" --body "Merging $HEAD_BRANCH_NAME into $1"

    if [ $? -eq 0 ]; then 
        echo '🎉 SUCCESS: Pull Request created!'; 
    else 
        echo '❌ ERROR: Failed to create Pull Request. You may need to run \"gh auth login\" or your branch may not be ready.'; 
        exit 1; 
    fi; 
else 
    echo '⚠️ CONFLICT: Branches cannot be merged cleanly. a promotion PR will be created.'; 
    echo 'Details from git merge-tree:'; 
    echo \"$MERGE_TREE_OUTPUT\"; 
    PROMOTION_BRANCH=$HEAD_BRANCH_NAME-$ORG_NAME

    echo 'Creating promotion branch: $PROMOTION_BRANCH'
    git fetch origin "$HEAD_BRANCH_NAME" || { echo "❌ git fetch failed"; exit 1; }

    git checkout -B $PROMOTION_BRANCH $HEAD_BRANCH_NAME || { echo "❌ Failed to create branch $PROMOTION_BRANCH from $HEAD_BRANCH_NAME"; exit 1; }

    git push origin $PROMOTION_BRANCH || { echo "❌ git push failed"; exit 1; }

    echo 'Creating Pull Request... (This may prompt you to push your branch)';
    gh pr create --base $1 --head $PROMOTION_BRANCH --title \"$HEAD_BRANCH_NAME-$ORG_NAME\" --body "Merging $HEAD_BRANCH_NAME into $1"

    git switch $HEAD_BRANCH_NAME
    exit 0; 
fi