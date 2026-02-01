# ANIMINA Dating Platform

ANIMINA is a web based dating platform. In case you have a question do not
hesitate to contact Stefan Wintermeyer <sw@wintermeyer-consulting.de>

![Screenshot of an admin ANIMINA view](https://github.com/animina-dating/animina/blob/main/priv/static/images/admin-screenshot.png?raw=true)

> [!NOTE]
> Project founder Stefan Wintermeyer gave a (German) talk about the first
> ANIMINA Beta at [FrOSCon](https://froscon.org).
>
> - [video recording](https://media.ccc.de/v/froscon2024-3060-parship_tinder_animina_und_co)
> - [slides](https://speakerdeck.com/wintermeyer/disassembling-online-dating-froscon-2024)

## Tech Stack

Elixir 1.19, Phoenix 1.8, LiveView, Tailwind CSS, PostgreSQL

## Getting Started

**Prerequisites:** macOS or Linux, [PostgreSQL](https://www.postgresql.org), [mise](https://mise.jdx.dev) for version management (Erlang/OTP 28.3, Elixir 1.19 — pinned in `.tool-versions`)

```bash
git clone git@github.com:animina-dating/animina.git
cd animina
mise install
mix deps.get
mix ecto.setup
mix phx.server
```

Visit `http://localhost:4000` to see the landing page. Register at `/users/register`.

## Development

- `mix test` — run tests
- `mix precommit` — full quality check (compile, format, credo, test)

## Admin Access

Grant admin privileges to the first user via IEx:

```elixir
iex -S mix

user = Animina.Accounts.get_user_by_email("admin@example.com")
Animina.Accounts.assign_role(user, "admin")
```

After that, manage roles for other users through the web admin panel at `/admin/roles`.

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) — production deployment with hot code upgrades and CI/CD
- [TRANSLATING.md](TRANSLATING.md) — i18n workflow for all 9 languages
- [DESIGN.md](DESIGN.md) — design guidelines
- [docs/features/](docs/features/) — detailed feature specifications

## License

[MIT](LICENSE.md)
