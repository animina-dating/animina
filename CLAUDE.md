# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ANIMINA is a Phoenix/Elixir online dating platform.

## Architecture

### Contexts

The application is organized into these contexts:

- **Animina.Accounts** (`lib/animina/accounts/`) - Users, authentication, messages, bookmarks, reactions, credits, reports, user roles
  - Sub-modules: `Locations`, `Roles`, `SoftDelete`, `Statistics`
- **Animina.Photos** (`lib/animina/photos/`) - Photo upload, processing, moderation
  - Sub-modules: `Appeals`, `AuditLog`, `Blacklist`, `FileManagement`, `OllamaQueue`, `UrlSigning`
- **Animina.Traits** (`lib/animina/traits/`) - Categories, flags, user_flags (personality traits system with white/green/red flags)
  - Sub-modules: `Matching`, `Validations`
- **Animina.Moodboard** (`lib/animina/moodboard/`) - Profile moodboard items (photos, stories, combined cards)
- **Animina.Discovery** (`lib/animina/discovery/`) - Partner suggestions, scoring, popularity protection
  - Sub-modules: `Filters`, `Scorers`, `Popularity`, `Settings`
- **Animina.Messaging** (`lib/animina/messaging/`) - Conversations, messages, read receipts, blocking
  - Sub-modules: `UnreadNotifier`
- **Animina.GeoData** (`lib/animina/geo_data/`) - City data for location features
- **Animina.Utils** (`lib/animina/utils/`) - Shared utilities
  - `PaperTrail` - PaperTrail audit helpers
  - `Timezone` - Berlin timezone conversions

### Layout Convention

Every LiveView **must** wrap its content in `<Layouts.app flash={@flash} current_scope={@current_scope}>`. This shared layout component (`lib/animina_web/components/layouts.ex`) renders the ANIMINA navigation bar (with auth-aware links) and footer. Pages must **never** render their own inline nav or footer — use the shared layout so all pages look consistent.

**Page Width:** The layout automatically provides a `max-w-7xl` container with responsive padding (`px-4 sm:px-6 lg:px-8 py-8`). Pages should NOT add their own outer container. Instead:

- **Form pages** (settings, login, registration): Use `<div class="max-w-2xl mx-auto">` or `<div class="max-w-md mx-auto">` for narrower forms
- **Content pages** (moodboard, admin): Content will fill the max-w-7xl container by default
- **Full-width pages** (landing pages with background sections): Use `<Layouts.app ... full_width={true}>` to skip the container entirely and manage your own widths per section

LiveViews that need `@current_scope` must be inside a `live_session` with `on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}]` in the router.

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

**Always enforce business rules at the context level**, not only in LiveViews or controllers. UI-level checks are an optimisation for user experience (e.g. showing a modal), but the context must be the single source of truth. This ensures that seeds, IEx sessions, background jobs, and future code paths all respect the same constraints.

Example: flag limits are validated inside `Traits.add_user_flag/2` so every caller is protected. The LiveView then pattern-matches on the `{:error, :flag_limit_reached}` tuple to show a friendly modal.

### Bug Fix Conventions

When fixing bugs, always verify that the fix doesn't break related functionality. Run relevant tests and manually verify the feature still works end-to-end before considering the task complete.

Before marking a bug fix complete, explicitly verify:
1. The original bug is fixed
2. Related features still work (run the feature manually)
3. No visual regressions in UI elements like avatars and images

### Photo Display Convention

**ALWAYS** use `LivePhotoComponent` when displaying photos in LiveViews:

```heex
<.live_component
  module={AniminaWeb.LivePhotoComponent}
  id={"photo-#{@photo.id}"}
  photo={@photo}
  owner?={@is_owner}
  variant={:main}
  class="w-full h-auto"
/>
```

This ensures:
- Real-time status updates via PubSub subscriptions
- Correct status badges for owners (Processing, Analyzing, Under review, error messages)
- "In review" placeholder for non-owners when photo is not approved
- Automatic subscription cleanup on unmount

**Variants:** `:main` (default, full size) or `:thumbnail` (small)

For moodboard items, use `LiveMoodboardItemComponent` which wraps photo and story handling:

```heex
<.live_component
  module={AniminaWeb.LiveMoodboardItemComponent}
  id={"moodboard-item-#{@item.id}"}
  item={@item}
  owner?={@is_owner}
/>
```

**NEVER** render photos with plain `<img src={Photos.signed_url(photo)}>` in LiveViews — this bypasses real-time updates and status handling.

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

### Activity Logging Convention

When adding or modifying features that involve user actions, admin actions, or significant system events, add an `ActivityLog.log/4` call at the success path. The unified activity log lives in the `activity_logs` table and is viewable at `/admin/logs/activity`.

**Usage:**
```elixir
Animina.ActivityLog.log(category, event, summary,
  actor_id: who_did_it,
  subject_id: who_it_happened_to,
  metadata: %{"optional" => "details"}
)
```

**Categories & when to use them:**
- `"auth"` — login, logout, failed login, session events, sudo mode
- `"social"` — messages, conversations, profile visits, bookmarks, reactions, dismissals
- `"profile"` — profile field changes, flag changes, moodboard edits, account lifecycle
- `"admin"` — role changes, feature flag toggles, photo reviews, blacklist management
- `"system"` — photo processing, emails sent, AI analysis (bridge from existing domain logs)

**Rules:**
- `actor_id` = who performed the action (nil for system-initiated events)
- `subject_id` = which user was affected (nil when no specific user target, same as actor_id for self-actions)
- `summary` = pre-formatted one-liner readable in the admin log table (e.g. `"User Max sent a message to User Lisa"`)
- Only log at the success path — don't log failed operations (except `login_failed`)
- Use existing event names from `ActivityLogEntry.valid_events/0` — add new ones to the schema if needed

### Discovery Algorithm Documentation

When modifying any code in `lib/animina/discovery/`, `lib/animina/traits/matching.ex`, or the discovery-related feature flags in `lib/animina/feature_flags/`, update `DISCOVERY_ALGORITHM.md` to reflect the changes. This includes changes to filters, scoring weights, category multipliers, popularity protection, or the overall pipeline flow.
