# ANIMINA Dating Platform

ANIMINA is a web based dating platform. In case you have a question do not
hesitate to contact Stefan Wintermeyer <sw@wintermeyer-consulting.de>

![Screenshot of a demo ANIMINA profile](https://github.com/animina-dating/animina/blob/main/priv/static/images/profile-screenshot.webp?raw=true)

> [!WARNING]
> The current version a beta version. We appreciate all bug reports!

Please do submit bug reports or feature requests with an [issue](https://github.com/animina-dating/animina/issues/new).

For detailed feature specifications, see [docs/features/](docs/features/).

> [!NOTE]
> Project founder Stefan Wintermeyer gave a (German) talk about the first
> ANIMINA Beta at [FrOSCon](https://froscon.org).
>
> - [video recording](https://media.ccc.de/v/froscon2024-3060-parship_tinder_animina_und_co)
> - [slides](https://speakerdeck.com/wintermeyer/disassembling-online-dating-froscon-2024)

## Features

- **User Authentication**: Email/password registration and login with magic link support
- **User Profiles**: Display name, birthday, gender, height, 1-4 Wohnsitze (residences), and partner preferences
- **Auto-filled Partner Preferences**: Intelligent defaults based on gender and height
- **Wizard Registration**: 4-step wizard with progress indicator, Back/Next navigation, and per-step validation
- **German UI**: Registration and login forms in German ("Coastal Morning" design)
- **Geo Data**: Germany with 8000+ cities seeded

## ANIMINA Installation Guide for Developers

What we assume:

- macOS or Linux as an OS
- Installed [PostgreSQL](https://www.postgresql.org) database.
- Basic understanding of Elixir and the [Phoenix Framework](https://phoenixframework.org).

### Clone the Project

- Git clone the project with `git clone git@github.com:animina-dating/animina.git`
- `cd animina` into the local project clone

### Setup

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

Visit `http://localhost:4000` to see the landing page. Register at `/users/register`.

