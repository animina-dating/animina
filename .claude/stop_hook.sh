#!/usr/bin/env bash
# Claude Code stop hook: runs mix precommit, skips if triggered by a previous stop hook
jq -e '.stop_hook_active' >/dev/null 2>&1 && exit 0
cd /Users/stefan/GitHub/animina && mix precommit 2>&1 || exit 2
