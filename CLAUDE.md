# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ANIMINA is a Phoenix/Elixir dating platform using the Ash Framework for resource management. It uses PostgreSQL, Phoenix LiveView, and Tailwind CSS with a mobile-first approach.

## Common Commands

```bash
# Install dependencies
mix deps.get
cd assets && npm install && cd ..

# Database setup (uses Ash-specific commands)
mix ash_postgres.create
mix ash_postgres.migrate

# Generate new migration
mix ash_postgres.generate_migrations

# Seed demo data
mix seed_demo_system

# Start development server
iex -S mix phx.server

# Run without ML features (faster startup on limited hardware)
DISABLE_ML_FEATURES=true iex -S mix phx.server

# Pre-commit checks (run before committing)
mix format
mix credo
mix dialyzer
mix test

# Run single test file
mix test test/animina/accounts/user_test.exs

# Run specific test
mix test test/animina/accounts/user_test.exs:26
```

## Architecture

### Ash Framework Domains

The application uses Ash Framework with four domains:

- **Animina.Accounts** (`lib/animina/accounts/`) - Users, authentication, photos, messages, bookmarks, reactions, credits, reports
- **Animina.Narratives** (`lib/animina/narratives/`) - Stories, posts, headlines (user profile content)
- **Animina.Traits** (`lib/animina/traits/`) - Categories, flags, user_flags (personality traits system with white/green/red flags)
- **Animina.GeoData** (`lib/animina/geo_data/`) - City data for location features

### Key Resources

- `User` / `BasicUser` / `FastUser` - User accounts at different query optimization levels
- `Story` / `FastStory` - Profile narrative content
- `Photo` / `OptimizedPhoto` - User photos with multiple size variants
- `Flag` / `UserFlags` - Trait system (white=about me, green=like, red=dislike)
- `Message` / `Reaction` / `Bookmark` - User interactions

### User States

Users have states that control visibility: `normal`, `validated`, `under_investigation`, `banned`, `incognito`, `hibernate`, `archived`

State changes use actions like `User.hibernate/1`, `User.ban/1`, `User.normalize/1` etc.

### Photo Processing

Photos go through a GenServer pipeline (`lib/animina/genservers/photo/`) that handles optimization, tagging, and NSFW detection (when ML enabled).

### LiveView Structure

LiveViews are in `lib/animina_web/live/`. Key patterns:
- Uses `ash_authentication_live_session` for auth-protected routes
- Components organized in `lib/animina_web/components/` by feature

## Testing

- Unit tests: `test/animina/` - Test Ash resources directly
- LiveView tests: `test/animina_web/live/` - Integration tests
- Use `Animina.DataCase` for resource tests, `AniminaWeb.ConnCase` for web tests

## Frontend

- Mobile-first Tailwind CSS with dark mode support
- Minimal JavaScript - prefer Phoenix LiveView patterns
- Alpine.js available for client-side interactions
- Dev mailbox: `localhost:4000/dev/mailbox`

## LLM Integration

Uses Ollama with Llama3.1:8b for AI features. Configure LLM in `config/dev.exs` (`:llm_version`).
