#!/bin/bash
# This script is used to build the ANIMINA application on the production server.

set -euo pipefail

# Define a unique lock file name using the script's name to avoid conflicts
LOCKFILE="/tmp/animina-deploy.lock"

# Clean up the lock file on exit
cleanup() {
    rm -f "${LOCKFILE}"
}
trap cleanup EXIT

# Check if the script is already running
if [ -e "${LOCKFILE}" ]; then
    LOCK_PID=$(cat "${LOCKFILE}")
    if [ -n "${LOCK_PID}" ] && kill -0 "${LOCK_PID}" 2>/dev/null; then
        echo "ANIMINA deployment script is already running."
        exit 1
    else
        echo "Removing stale lock file."
        rm -f "${LOCKFILE}"
    fi
fi

# Store the current process ID in the lock file
echo $$ > "${LOCKFILE}"
chmod 600 "${LOCKFILE}"

# Define the source and destination directories
SRC_DIR="$HOME/GitHub/animina/"
DEST_DIR="$HOME/bin/animina/"

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
    logger -t animina "Deployment ${new_version}: Starting deployment"
    touch ~/deployment_is_happening

    # Update the version number in the mix.exs file
    sed -i "s/^\(\s*version:\s*\"\)[^\"]*\(.*\)$/\1${new_version}\2/" "$MIX_FILE"

    # Source asdf and perform build operations
    logger -t animina "Deployment ${new_version}: asdf install"
    . "$HOME/.asdf/asdf.sh"
    asdf install 
    logger -t animina "Deployment ${new_version}: mix deps.get --only prod"
    mix deps.get --only prod 
    logger -t animina "Deployment ${new_version}: MIX_ENV=prod mix compile"
    MIX_ENV=prod mix compile
    logger -t animina "Deployment ${new_version}: cd assets && npm install"
    cd assets && npm install
    cd .. 
    logger -t animina "Deployment ${new_version}: MIX_ENV=prod mix assets.deploy"
    MIX_ENV=prod mix assets.deploy

    logger -t animina "Deployment ${new_version}: MIX_ENV=prod mix phx.gen.release"
    MIX_ENV=prod mix phx.gen.release
    logger -t animina "Deployment ${new_version}: MIX_ENV=prod mix release"
    MIX_ENV=prod mix release
    logger -t animina "Deployment ${new_version}: Animina.Release.migrate"
    . ~/.bashrc && _build/prod/rel/animina/bin/animina eval "Animina.Release.migrate"

    logger -t animina "Deployment ${new_version}: Linking /var/www/animina.de"
    rm -f "/var/www/animina.de"
    ln -sf "${DEST_DIR}_build/prod/rel/animina/lib/animina-${new_version}/priv/static" "/var/www/animina.de"
    mkdir -p /home/animina/uploads
    
    # link ~/uploads as a shared directory
    logger -t animina "Deployment ${new_version}: Linking ~/uploads"
    rm -f "${DEST_DIR}_build/prod/rel/animina/lib/animina-${new_version}/priv/static/uploads/.gitkeep"
    rmdir "${DEST_DIR}_build/prod/rel/animina/lib/animina-${new_version}/priv/static/uploads"
    ln -sf "/home/animina/uploads" "${DEST_DIR}_build/prod/rel/animina/lib/animina-${new_version}/priv/static/uploads"

    if [ ! -L ~/bin/animina/priv/static/uploads ]; then
      rm ~/bin/animina/priv/static/uploads/.gitkeep
      rmdir ~/bin/animina/priv/static/uploads
      ln -s /home/animina/uploads ~/bin/animina/priv/static/uploads
    fi

    # Stop the old version and start the new one
    logger -t animina "Deployment ${new_version}: systemctl restart animina"
    sudo /bin/systemctl restart animina

    rm ~/deployment_is_happening

    logger -t animina "Deployment ${new_version}: successully deployed"
else
    echo "No new version available."
fi
