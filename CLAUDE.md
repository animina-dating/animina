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
