#!/bin/bash
# This script is used to build the ANIMINA application on the production server.

set -euo pipefail

LOCKFILE=$(mktemp /tmp/animina-deploy.lock.XXXXXX)

# Clean up the lock file on exit
cleanup() {
    rm -f "${LOCKFILE}"
}
trap cleanup EXIT

# Check if the script is already running
if [ -e "${LOCKFILE}" ] && kill -0 "$(cat "${LOCKFILE}")"; then
    echo "ANIMINA deployment script is already running."
    exit 1
fi

# Store the current process ID in the lock file
echo $$ > "${LOCKFILE}"
chmod 600 "${LOCKFILE}"

# Define the source and destination directories
SRC_DIR="$HOME/GitHub/animina/"
DEST_DIR="$HOME/bin/animina/"

# Ensure required commands are available
required_commands=("git" "rsync" "sed" "grep" "date" "asdf" "npm" "mix")
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed."
        exit 1
    fi
done

# Create version number
cd "$SRC_DIR"
timestamp=$(git log -1 --format="%at")
new_version="$(date -d @$timestamp +%Y%m%d.1%H%M.1%S)"

# Ensure the destination directory exists
mkdir -p "$DEST_DIR"

# Define the path to the mix.exs file
MIX_FILE="mix.exs"
DEST_MIX_FILE="$DEST_DIR$MIX_FILE"

# Function to extract the version number from mix.exs
extract_version() {
    grep -oP 'version: "\K[^\"]+' "$1"
}

# Back up the version number from the destination mix.exs file
if [ -f "$DEST_MIX_FILE" ]; then
    DEST_VERSION=$(extract_version "$DEST_MIX_FILE")
else
    # If the mix.exs file does not exist, set the version to "0.0.1"
    DEST_VERSION="0.0.1"
fi

# Perform the rsync operation
rsync -a --delete --exclude='.git' --exclude='.github' "$SRC_DIR" "$DEST_DIR"

# Restore the version number in the mix.exs file if it was backed up
if [ -n "$DEST_VERSION" ]; then
    sed -i -E "s/(version: \")([^\"]+)(\")/\1$DEST_VERSION\3/" "$DEST_MIX_FILE"
else
    echo "No backup version number to restore."
    exit 1
fi

# Extract the current version from mix.exs
cd "$DEST_DIR"
current_version=$(extract_version "$MIX_FILE")

# Compare the current version with the new version
if [ "$current_version" != "$new_version" ]; then
    echo "Old version: ${current_version}"
    echo "New version: ${new_version}"

    # Update the version number in the mix.exs file
    sed -i "s/^\(\s*version:\s*\"\)[^\"]*\(.*\)$/\1${new_version}\2/" "$MIX_FILE"

    # Source asdf and perform build operations
    . "$HOME/.asdf/asdf.sh"
    asdf install 
    mix deps.get --only prod 
    MIX_ENV=prod mix compile
    cd assets && npm install
    cd .. 
    MIX_ENV=prod mix assets.deploy

    MIX_ENV=prod mix phx.gen.release
    MIX_ENV=prod mix release
    _build/prod/rel/animina/bin/animina eval "Animina.Release.migrate"
else
    echo "No new version available."
fi
