#!/bin/bash
set -euo pipefail

# =============================================================================
# Production Deployment Script for Phoenix/Elixir
#
# Features:
#   - Hot code upgrades with automatic fallback to cold deploy
#   - Pre-deployment database backups (configurable)
#   - Automatic rollback on failure (migration, startup, health check)
#   - Health checks with retries
#   - Release cleanup
#
# Usage:
#   ./scripts/deploy.sh
#
# Environment variables (from shared/.env):
#   ENABLE_PREDEPLOY_BACKUP - Set to "false" to skip pre-deploy DB backup
#   DATABASE_URL             - PostgreSQL connection string
#   PORT                     - Application port (default: 4000)
# =============================================================================

# --- Configuration -----------------------------------------------------------
RELEASE_NAME="animina"
SERVICE_NAME="animina2"
DEPLOY_DIR="${DEPLOY_DIR:-/var/www/animina.de}"
CURRENT_LINK="${DEPLOY_DIR}/current"
SHARED_DIR="${DEPLOY_DIR}/shared"
BACKUP_DIR="${SHARED_DIR}/backups"
HOT_UPGRADES_DIR="${SHARED_DIR}/hot-upgrades"
RELEASES_DIR="${DEPLOY_DIR}/releases"
RELEASE_DIR="${RELEASES_DIR}/$(date +%Y%m%d%H%M%S)"
TARBALL=$(ls _build/prod/${RELEASE_NAME}-*.tar.gz 2>/dev/null | head -n1)
MAX_RELEASES=5
MAX_BACKUPS=10
HEALTH_CHECK_RETRIES=6
HEALTH_CHECK_INTERVAL=5
APP_PORT="${PORT:-4045}"

# --- Helper functions --------------------------------------------------------
log() { echo "==> $1"; }
err() { echo "!!! ERROR: $1" >&2; }

cleanup_failed_release() {
  if [ -d "$RELEASE_DIR" ]; then
    log "Cleaning up failed release directory: $RELEASE_DIR"
    rm -rf "$RELEASE_DIR"
  fi
}

rollback_symlink() {
  local previous
  previous=$(ls -t "$RELEASES_DIR" 2>/dev/null | head -n1)
  if [ -n "$previous" ] && [ -d "$RELEASES_DIR/$previous" ]; then
    log "Rolling back to previous release: $previous"
    ln -sfn "$RELEASES_DIR/$previous" "$CURRENT_LINK"
    return 0
  fi
  err "No previous release found for rollback"
  return 1
}

health_check() {
  local attempt=1
  while [ $attempt -le $HEALTH_CHECK_RETRIES ]; do
    log "Health check attempt $attempt/$HEALTH_CHECK_RETRIES..."
    if curl -sf "http://localhost:${APP_PORT}/health" > /dev/null 2>&1; then
      log "Health check passed"
      return 0
    fi
    sleep "$HEALTH_CHECK_INTERVAL"
    attempt=$((attempt + 1))
  done
  err "Health check failed after $HEALTH_CHECK_RETRIES attempts"
  return 1
}

cleanup_old_releases() {
  log "Cleaning up old releases (keeping last $MAX_RELEASES)..."
  cd "$RELEASES_DIR"
  ls -t | tail -n +$((MAX_RELEASES + 1)) | xargs -r rm -rf
  cd - > /dev/null
}

cleanup_old_backups() {
  log "Cleaning up old backups (keeping last $MAX_BACKUPS)..."
  ls -t "$BACKUP_DIR"/pre-deploy-*.dump 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -f
}

# --- Detect deploy strategy -------------------------------------------------
needs_cold_deploy() {
  # Check commit messages for cold deploy markers
  local last_commit_msg
  last_commit_msg=$(git log -1 --pretty=%B 2>/dev/null || echo "")

  if echo "$last_commit_msg" | grep -qiE '\[(cold-deploy|restart|supervision)\]'; then
    log "Cold deploy forced by commit message tag"
    return 0
  fi

  # Check if there are pending migrations
  if [ -d "$RELEASE_DIR/lib/${RELEASE_NAME}-"*/priv/repo/migrations ] 2>/dev/null; then
    local current_migrations=""
    if [ -L "$CURRENT_LINK" ] && [ -d "$CURRENT_LINK" ]; then
      current_migrations=$(ls "$CURRENT_LINK/lib/${RELEASE_NAME}-"*/priv/repo/migrations/ 2>/dev/null | sort)
    fi
    local new_migrations
    new_migrations=$(ls "$RELEASE_DIR/lib/${RELEASE_NAME}-"*/priv/repo/migrations/ 2>/dev/null | sort)
    if [ "$current_migrations" != "$new_migrations" ]; then
      log "New migrations detected - cold deploy required"
      return 0
    fi
  fi

  # Check if hot upgrades directory exists and is enabled
  if [ ! -d "$HOT_UPGRADES_DIR" ]; then
    return 0
  fi

  # Check if the application is running
  if ! systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    log "Application is not running - cold deploy required"
    return 0
  fi

  return 1
}

# --- Pre-deployment backup ---------------------------------------------------
pre_deploy_backup() {
  # Source env to get DATABASE_URL and ENABLE_PREDEPLOY_BACKUP
  if [ -f "$SHARED_DIR/.env" ]; then
    set -a
    source "$SHARED_DIR/.env"
    set +a
  fi

  if [ "${ENABLE_PREDEPLOY_BACKUP:-true}" = "false" ]; then
    log "Pre-deployment backup disabled via ENABLE_PREDEPLOY_BACKUP=false"
    return 0
  fi

  mkdir -p "$BACKUP_DIR"
  local backup_file="$BACKUP_DIR/pre-deploy-$(date +%Y%m%d%H%M%S).dump"
  log "Creating pre-deployment database backup: $backup_file"

  if pg_dump --format=custom --compress=6 -f "$backup_file" "$DATABASE_URL" 2>/dev/null; then
    log "Backup created successfully ($(du -h "$backup_file" | cut -f1))"
    cleanup_old_backups
  else
    err "Pre-deployment backup failed - continuing without backup"
  fi
}

# --- Main deployment ---------------------------------------------------------
main() {
  log "Starting deployment of ${RELEASE_NAME} (service: ${SERVICE_NAME})"
  log "Release directory: $RELEASE_DIR"

  # Verify tarball exists
  if [ -z "$TARBALL" ] || [ ! -f "$TARBALL" ]; then
    err "No release tarball found in _build/prod/"
    exit 1
  fi

  # Create release directory and extract
  log "Creating release directory"
  mkdir -p "$RELEASE_DIR"

  log "Extracting release tarball: $TARBALL"
  tar -xzf "$TARBALL" -C "$RELEASE_DIR"

  # Source environment
  if [ -f "$SHARED_DIR/.env" ]; then
    set -a
    source "$SHARED_DIR/.env"
    set +a
  fi

  # Save previous release path for rollback
  local previous_release=""
  if [ -L "$CURRENT_LINK" ]; then
    previous_release=$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)
  fi

  # Determine deploy strategy
  if needs_cold_deploy; then
    log "Using COLD deploy strategy"

    # Pre-deployment backup
    pre_deploy_backup

    # Run migrations
    log "Running database migrations..."
    if ! "$RELEASE_DIR/bin/migrate" 2>&1; then
      err "Migration failed!"
      cleanup_failed_release
      exit 1
    fi
    log "Migrations completed successfully"

    # Update symlink
    log "Updating current symlink"
    ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"

    # Restart application
    log "Restarting application..."
    if ! sudo systemctl restart "$SERVICE_NAME" 2>&1; then
      err "Failed to restart application"
      if [ -n "$previous_release" ] && [ -d "$previous_release" ]; then
        rollback_symlink
        sudo systemctl restart "$SERVICE_NAME" 2>&1 || true
      fi
      cleanup_failed_release
      exit 1
    fi
  else
    log "Using HOT deploy strategy"

    # Update symlink first (for next cold restart to use new code)
    log "Updating current symlink"
    ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"

    # Copy beam files to hot-upgrades directory for code loading
    log "Staging hot upgrade files..."
    rm -rf "${HOT_UPGRADES_DIR:?}/"*
    if [ -d "$RELEASE_DIR/lib" ]; then
      cp -r "$RELEASE_DIR/lib" "$HOT_UPGRADES_DIR/"
    fi

    # Signal the running application to reload
    # The HotDeploy GenServer watches this directory
    touch "$HOT_UPGRADES_DIR/.reload"
    log "Hot upgrade signal sent"
  fi

  # Health check
  log "Waiting for application to become healthy..."
  sleep 2
  if ! health_check; then
    err "Deployment failed health check!"
    if [ -n "$previous_release" ] && [ -d "$previous_release" ]; then
      ln -sfn "$previous_release" "$CURRENT_LINK"
      sudo systemctl restart "$SERVICE_NAME" 2>&1 || true
      log "Rolled back to previous release"
    fi
    cleanup_failed_release
    exit 1
  fi

  # Cleanup
  cleanup_old_releases
  log "Deployment completed successfully!"
}

main "$@"
