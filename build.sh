#!/bin/bash

if [ $(id --user) -eq 0 ]; then
    echo "Do not run this script as root."
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "$# packages provided as argument."
    exit 1
fi

WORKFLOW="aur-build.yml"
REPO="asahi-xd/AUR-Build"
LOCAL_REPO_NAME="gh-aur-builds"
LOCAL_REPO_DIR="/mnt/Data_Drive/.local/pacman/repo"
DOWNLOAD_TMP_DIR="/mnt/Data_Drive/.local/pacman/tmp"

# Ensure directories exist
mkdir -p "$LOCAL_REPO_DIR"/"$LOCAL_REPO_NAME"


printf "Verifying that the package names provided are valid...\n\n"

packages=("$@")

for i in "${packages[@]}"; do
    if ! yay -Si "$i" > /dev/null 2>&1 ; then
        invalid_pkgs+=($i)
    fi
done

if [ ${#invalid_pkgs[@]} -ne 0 ]; then
    echo "Invalid package name(s) provided:"
    echo ${invalid_pkgs[@]}
    exit 1
fi

echo "Do you want to read the PKGBUILDs for the provided package(s)? [yes/no]"
echo "Press ENTER for the default choice [yes]. Or Press Ctrl+C to cancel the script and exit."

read choice

case "$choice" in
    "yes" )
        echo "Do something"
    ;;
    "no" )
        echo "Do something else"
    ;;
    "" )
        echo "No choice made, defaulting to [yes]."
    ;;
    * )
        echo "Invalid choice. Exiting script..."
        exit 1
    ;;
esac


printf "\nRunning the workflow...\n\n"
printf "Building package(s): '$@'\n"

shopt -s globstar

gh workflow run \
    "$WORKFLOW" -R "$REPO" \
    -f packages="$@" \
    && sleep 5 \
    && RUN_ID=$(gh run list --workflow=$WORKFLOW -R $REPO --limit 1 --json databaseId --jq '.[0].databaseId') \
    && gh run -R "$REPO" watch $RUN_ID \
    && gh run -R "$REPO" download $RUN_ID --dir "$DOWNLOAD_TMP_DIR" \
    && ARTIFACT_NAME=$(gh api repos/$REPO/actions/runs/$RUN_ID/artifacts --jq '.artifacts[0].name') \
    && echo $ARTIFACT_NAME \
    && cp -r "$DOWNLOAD_TMP_DIR"/"$ARTIFACT_NAME"/**/*.pkg.tar.zst "$LOCAL_REPO_DIR"/"$LOCAL_REPO_NAME" \
    && echo "Adding package(s) to local repository..." \
    && repo-add "$LOCAL_REPO_DIR"/"$LOCAL_REPO_NAME"/"$LOCAL_REPO_NAME".db.tar.zst "$LOCAL_REPO_DIR"/"$LOCAL_REPO_NAME"/*.pkg.tar.zst \
    && printf "\nSuccessfully built and added packages to local repo!\n"



