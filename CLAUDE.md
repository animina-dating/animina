# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ANIMINA is a Phoenix/Elixir dating platform using Ecto and PostgreSQL for data management. It uses Phoenix LiveView and Tailwind CSS with a mobile-first approach.

## Architecture

### Contexts

The application is organized into these contexts:

- **Animina.Accounts** (`lib/animina/accounts/`) - Users, authentication, messages, bookmarks, reactions, credits, reports
- **Animina.Traits** (`lib/animina/traits/`) - Categories, flags, user_flags (personality traits system with white/green/red flags)
- **Animina.GeoData** (`lib/animina/geo_data/`) - City data for location features

### Database Conventions

- All resources use UUIDs for primary keys, not auto-incrementing integers
