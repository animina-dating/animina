# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ANIMINA is a Phoenix/Elixir online dating platform.

## Architecture

### Contexts

The application is organized into these contexts:

- **Animina.Accounts** (`lib/animina/accounts/`) - Users, authentication, messages, bookmarks, reactions, credits, reports, user roles
- **Animina.Traits** (`lib/animina/traits/`) - Categories, flags, user_flags (personality traits system with white/green/red flags)
- **Animina.GeoData** (`lib/animina/geo_data/`) - City data for location features

### Layout Convention

Every LiveView **must** wrap its content in `<Layouts.app flash={@flash} current_scope={@current_scope}>`. This shared layout component (`lib/animina_web/components/layouts.ex`) renders the ANIMINA navigation bar (with auth-aware links) and footer. Pages must **never** render their own inline nav or footer — use the shared layout so all pages look consistent.

LiveViews that need `@current_scope` must be inside a `live_session` with `on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}]` in the router.

### Deploy Conventions

- **Cold deploy**: Add `[cold-deploy]` to the commit message (e.g. `git commit -m "Add new worker [cold-deploy]"`). Also recognized: `[restart]`, `[supervision]`.
- **Hot deploy** (default): Any commit without these tags triggers a hot code upgrade (zero downtime).
- The deploy script (`scripts/deploy.sh`) detects these tags automatically.

### Role System

Three roles exist: `user` (implicit, always present), `moderator`, and `admin`. Roles are stored in the `user_roles` table. Admin-only routes use `on_mount: [{AniminaWeb.UserAuth, :require_admin}]`; moderator routes use `:require_moderator`. The admin panel lives under `/admin/roles`. Role switching is handled by `RoleController.switch/2` and stored in the session as `current_role`.

### Database Conventions

- All resources use UUIDs for primary keys, not auto-incrementing integers

### Translation Conventions

Translation work is split across sessions to avoid context limits.

#### During feature work (same session as code changes)

1. **All user-facing strings must use Gettext** — wrap UI text in `gettext("...")`, validation errors in `dgettext("errors", "...")`, and count-based text in `ngettext()`/`dngettext()`.

2. **After adding or changing `gettext()` calls, run `mix gettext.extract --merge`** to update `.pot` templates and merge new entries into all `.po` files.

3. **Only translate English and German** during the feature session. Fill in `msgstr` for `en` and `de` only. Other languages may have empty `msgstr ""` temporarily.

4. **Email templates** — during feature work, update templates for `en` and `de` only. Preserve `<%= @variable %>` placeholders and the subject/`---`/body format.

#### After feature work (separate translation sessions)

5. **Translate remaining languages in dedicated sessions** — do 2-3 languages per session. Each session reads the English `.po` file as reference and fills in the target language files. Supported languages: tr, ru, ar, pl, fr, es, uk.

6. **Plural forms** — languages have different plural counts: 2 forms for de/en/tr/fr/es, 3 forms for ru/pl/uk, 6 forms for ar. Provide the correct number of `msgstr[N]` entries for each language.

7. **Email templates** — translate remaining locale directories under `priv/email_templates/{locale}/` in the same translation sessions.

8. **Reference `TRANSLATING.md`** for full details on file structure, plural rules, and translation workflow.
