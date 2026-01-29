#!/bin/bash
set -euo pipefail

# =============================================================================
# Rollback Utility for Phoenix/Elixir Deployment
#
# Usage:
#   ./scripts/rollback.sh              # Interactive menu
#   ./scripts/rollback.sh previous     # Quick rollback to previous release
#   ./scripts/rollback.sh list         # List all releases
#   ./scripts/rollback.sh backups      # List all database backups
# =============================================================================

APP_NAME="${APP_NAME:-animina}"
DEPLOY_DIR="${DEPLOY_DIR:-/var/www/${APP_NAME}}"
CURRENT_LINK="${DEPLOY_DIR}/current"
RELEASES_DIR="${DEPLOY_DIR}/releases"
BACKUP_DIR="${DEPLOY_DIR}/shared/backups"

log() { echo "==> $1"; }
err() { echo "!!! ERROR: $1" >&2; }

current_release() {
  if [ -L "$CURRENT_LINK" ]; then
    basename "$(readlink -f "$CURRENT_LINK")"
  else
    echo "(none)"
  fi
}

list_releases() {
  echo ""
  echo "Available releases (newest first):"
  echo "-----------------------------------"
  local current
  current=$(current_release)
  local i=1
  for release in $(ls -t "$RELEASES_DIR" 2>/dev/null); do
    local marker=""
    if [ "$release" = "$current" ]; then
      marker=" <-- CURRENT"
    fi
    echo "  $i) $release$marker"
    i=$((i + 1))
  done
  echo ""
}

list_backups() {
  echo ""
  echo "Available database backups (newest first):"
  echo "--------------------------------------------"
  local i=1
  for backup in $(ls -t "$BACKUP_DIR" 2>/dev/null); do
    local size
    size=$(du -h "$BACKUP_DIR/$backup" | cut -f1)
    echo "  $i) $backup ($size)"
    i=$((i + 1))
  done
  if [ $i -eq 1 ]; then
    echo "  (no backups found)"
  fi
  echo ""
}

rollback_to_release() {
  local target="$1"
  local target_dir="$RELEASES_DIR/$target"

  if [ ! -d "$target_dir" ]; then
    err "Release not found: $target"
    return 1
  fi

  log "Rolling back to release: $target"
  ln -sfn "$target_dir" "$CURRENT_LINK"

  log "Restarting application..."
  sudo systemctl restart "$APP_NAME"

  sleep 3
  if systemctl is-active --quiet "$APP_NAME"; then
    log "Rollback successful! Application is running."
  else
    err "Application failed to start after rollback."
    echo "Check logs: sudo journalctl -u $APP_NAME -n 50"
    return 1
  fi
}

rollback_to_previous() {
  local current
  current=$(current_release)
  local previous
  previous=$(ls -t "$RELEASES_DIR" 2>/dev/null | grep -v "^${current}$" | head -n1)

  if [ -z "$previous" ]; then
    err "No previous release found"
    return 1
  fi

  rollback_to_release "$previous"
}

restore_backup() {
  local backup_file="$1"
  local full_path="$BACKUP_DIR/$backup_file"

  if [ ! -f "$full_path" ]; then
    err "Backup not found: $full_path"
    return 1
  fi

  # Source environment for DATABASE_URL
  if [ -f "$DEPLOY_DIR/shared/.env" ]; then
    set -a
    source "$DEPLOY_DIR/shared/.env"
    set +a
  fi

  echo ""
  echo "WARNING: This will restore the database from backup."
  echo "File: $backup_file"
  echo ""
  read -rp "Are you sure? (y/N) " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    return 0
  fi

  log "Stopping application..."
  sudo systemctl stop "$APP_NAME"

  log "Restoring database from: $backup_file"
  if [[ "$backup_file" == *.dump ]]; then
    # PostgreSQL custom format
    pg_restore --clean --if-exists --no-owner -d "$DATABASE_URL" "$full_path"
  elif [[ "$backup_file" == *.sql.gz ]]; then
    # Gzipped SQL format
    gunzip -c "$full_path" | psql "$DATABASE_URL"
  else
    err "Unknown backup format: $backup_file"
    return 1
  fi

  log "Starting application..."
  sudo systemctl start "$APP_NAME"

  sleep 3
  if systemctl is-active --quiet "$APP_NAME"; then
    log "Database restored and application restarted successfully."
  else
    err "Application failed to start after database restore."
    echo "Check logs: sudo journalctl -u $APP_NAME -n 50"
    return 1
  fi
}

show_status() {
  echo ""
  echo "=== Deployment Status ==="
  echo "Application: $APP_NAME"
  echo "Current release: $(current_release)"
  echo "Service status: $(systemctl is-active "$APP_NAME" 2>/dev/null || echo 'unknown')"
  echo ""
  echo "Releases: $(ls "$RELEASES_DIR" 2>/dev/null | wc -l | tr -d ' ')"
  echo "Backups:  $(ls "$BACKUP_DIR" 2>/dev/null | wc -l | tr -d ' ')"
  echo ""

  echo "Recent logs:"
  sudo journalctl -u "$APP_NAME" -n 10 --no-pager 2>/dev/null || echo "  (unable to read logs)"
  echo ""
}

interactive_menu() {
  while true; do
    echo ""
    echo "=== $APP_NAME Rollback Utility ==="
    echo "  1) Rollback to previous release"
    echo "  2) Select specific release"
    echo "  3) List all releases"
    echo "  4) Restore database from backup"
    echo "  5) List all backups"
    echo "  6) Show status"
    echo "  7) View recent logs"
    echo "  q) Quit"
    echo ""
    read -rp "Choose an option: " choice

    case "$choice" in
      1) rollback_to_previous ;;
      2)
        list_releases
        read -rp "Enter release name (timestamp): " release_name
        if [ -n "$release_name" ]; then
          rollback_to_release "$release_name"
        fi
        ;;
      3) list_releases ;;
      4)
        list_backups
        read -rp "Enter backup filename: " backup_name
        if [ -n "$backup_name" ]; then
          restore_backup "$backup_name"
        fi
        ;;
      5) list_backups ;;
      6) show_status ;;
      7) sudo journalctl -u "$APP_NAME" -n 50 --no-pager 2>/dev/null ;;
      q|Q) echo "Bye."; exit 0 ;;
      *) echo "Invalid option." ;;
    esac
  done
}

# --- Main -------------------------------------------------------------------
case "${1:-}" in
  previous)
    rollback_to_previous
    ;;
  list)
    list_releases
    ;;
  backups)
    list_backups
    ;;
  status)
    show_status
    ;;
  "")
    interactive_menu
    ;;
  *)
    echo "Usage: $0 [previous|list|backups|status]"
    exit 1
    ;;
esac
