# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ANIMINA is a Phoenix/Elixir online dating platform.

## Build & Test

- `mix deps.get` — install dependencies
- `mix ecto.setup` — create and migrate database, run seeds
- `mix test` — run test suite
- `mix test test/path/to_test.exs` — run a specific test file
- `mix format` — format code
- `mix credo --strict` — lint
- `mix phx.server` — start dev server
- `mix gettext.extract --merge` — update translations after changing gettext calls

## Architecture

### Contexts

Contexts live under `lib/animina/`. Explore the directory for current structure and sub-modules.

### Deploy Conventions

- **Cold deploy**: Add `[cold-deploy]` to the commit message (e.g. `git commit -m "Add new worker [cold-deploy]"`). Also recognized: `[restart]`, `[supervision]`.
- **Hot deploy** (default): Any commit without these tags triggers a hot code upgrade (zero downtime).
- The deploy script (`scripts/deploy.sh`) detects these tags automatically.

### Role System

Three roles exist: `user` (implicit, always present), `moderator`, and `admin`. Roles are stored in the `user_roles` table. Admin-only routes use `on_mount: [{AniminaWeb.UserAuth, :require_admin}]`; moderator routes use `:require_moderator`. The admin panel lives under `/admin/roles`. Role switching is handled by `RoleController.switch/2` and stored in the session as `current_role`.

### Database Conventions

- All resources use UUIDs for primary keys, not auto-incrementing integers

### Time Convention (TimeMachine)

**ALWAYS** use `Animina.TimeMachine` instead of `DateTime.utc_now()` / `Date.utc_today()` in business logic code. This enables dev-only time travel for testing time-sensitive features (cooldowns, grace periods, statistics, age calculations, etc.).

- `TimeMachine.utc_now()` — replaces `DateTime.utc_now()`
- `TimeMachine.utc_now(:second)` — replaces `DateTime.utc_now(:second)`
- `TimeMachine.utc_today()` — replaces `Date.utc_today()`

In prod/test these compile to direct passthroughs with zero overhead. In dev, they respect a time offset set via the "Time Travel" UI in the profile dropdown.

**Exceptions** — keep `DateTime.utc_now()` for:
- Auth/security: PIN expiry, sudo mode, token validation, `confirmed_at`, `terms_accepted_at`
- Ecto `timestamps()` (automatic `inserted_at`/`updated_at`)
- URL signing (`daily_secret`)
- Ollama debug/timing tools
- Presence tracking (`System.system_time`)

### Validation Convention

Enforce business rules at the context level. Example: flag limits are validated inside `Traits.add_user_flag/2`; the LiveView pattern-matches on `{:error, :flag_limit_reached}` to show a friendly modal.

### Photo Display Convention

**ALWAYS** use `LivePhotoComponent` and `LiveMoodboardItemComponent` when displaying photos in LiveViews. **NEVER** use plain `<img src={Photos.signed_url(photo)}>` — these components handle real-time PubSub updates, status badges, review placeholders, and subscription cleanup. Variants: `:main` (full size) or `:thumbnail`.

### Translation Conventions

All user-facing strings use Gettext. During feature work, translate EN + DE only; other languages (tr, ru, ar, pl, fr, es, uk) in dedicated sessions (2-3 per session). See `TRANSLATING.md` for full workflow, plural rules, and email template details.

### Activity Logging Convention

Log significant user/admin/system actions via `Animina.ActivityLog.log(category, event, summary, opts)` at the success path. Categories: `"auth"`, `"social"`, `"profile"`, `"admin"`, `"system"`. See `ActivityLogEntry.valid_events/0` for event names. The log is viewable at `/admin/logs/activity`.

### Discovery Algorithm Documentation

When modifying any code in `lib/animina/discovery/`, `lib/animina/traits/matching.ex`, or the discovery-related feature flags in `lib/animina/feature_flags/`, update `DISCOVERY_ALGORITHM.md` to reflect the changes. This includes changes to filters, scoring weights, category multipliers, popularity protection, or the overall pipeline flow.
