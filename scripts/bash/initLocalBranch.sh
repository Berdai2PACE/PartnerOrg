git_remote=$(git config --get remote.origin.url)
if [ -n "$1" ]; then
    folder="$(echo $1 | sed 's/ /-/g')"
    echo  folder : $folder
fi

if [ -n "$2" ]; then
    prefix=$2
    echo  prefix : $prefix
fi

# Example : 
# {work_directory} = Desktop/MonProjet/Tickets/

# Example :
# {source_branch_name} = CICDBase
# {git_remote} = https://{PERSONAL_ACCESS_TOKEN}@github.com/Nanon22/Projet.git
git clone -b main $git_remote ../"$folder"  

cd ../"$folder"

git checkout -b "$prefix$folder"

git push -u origin HEAD:"$prefix$folder"