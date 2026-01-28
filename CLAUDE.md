# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ANIMINA is a Phoenix/Elixir online dating platform.

## Architecture

### Contexts

The application is organized into these contexts:

- **Animina.Accounts** (`lib/animina/accounts/`) - Users, authentication, messages, bookmarks, reactions, credits, reports
- **Animina.Traits** (`lib/animina/traits/`) - Categories, flags, user_flags (personality traits system with white/green/red flags)
- **Animina.GeoData** (`lib/animina/geo_data/`) - City data for location features

### Layout Convention

Every LiveView **must** wrap its content in `<Layouts.app flash={@flash} current_scope={@current_scope}>`. This shared layout component (`lib/animina_web/components/layouts.ex`) renders the ANIMINA navigation bar (with auth-aware links) and footer. Pages must **never** render their own inline nav or footer — use the shared layout so all pages look consistent.

LiveViews that need `@current_scope` must be inside a `live_session` with `on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}]` in the router.

### Database Conventions

- All resources use UUIDs for primary keys, not auto-incrementing integers
