# Animina Dating Platform

Animina is a web based dating platform. It is initially targeted at the
German market. In case you have a question do not hesitate to contact
Stefan Wintermeyer <sw@wintermeyer-consulting.de>

Please do submit bug reports or feature requests with an [issue](https://github.com/animina-dating/animina/issues/new).

## I have no time for this! Tell me how to setup a dev system!

I assume that you have a locally hosted PostgreSQL database.

- Install [asdf](https://asdf-vm.com)
- Git clone the project
- cd into the local project directory
- `asdf install` installs the needed Elixir and Erlang versions
- `mix deps.get` or `DISABLE_ML_FEATURES=true mix deps.get` if you wish to not install the ML dependencies
- `mix ash_postgres.create` to create the database
- `mix ash_postgres.migrate` to run migrations
- `mix seed_demo_system` creates dummy accounts and lists them.
- `iex -S mix phx.server` or `DISABLE_ML_FEATURES=true iex -S mix phx.server` if you wish to start the server without ML features
- `cd assets && npm install` to install Alpine.js
- open http://localhost:4000 in your browser

## Development

We use:

  * [Elixir](https://elixir-lang.org/install.html)
  * [Phoenix](https://hexdocs.pm/phoenix/installation.html)
  * [PostgreSQL](https://www.postgresql.org/download/)

Probably the easiest way to install Elixir and Erlang is to use
[asdf](https://asdf-vm.com) with the command `asdf install`.

NOTE: Have a look at https://elixir-phoenix-ash.com if you are new to Elixir, Phoenix or Ash.

## Ash Framework

We use the [Ash Framework](https://ash-hq.org).

### Database Migrations

- `mix ash_postgres.create` to create the database
- `mix ash_postgres.migrate` to run migrations
- `mix ash_postgres.drop` to drop the database
- `mix ash_postgres.reset` to drop, create and migrate the database

Basic seeding is been automatically done by special migrations.

### Demo Accounts

In the development environment you can use `mix seed_demo_system` to create a couple of 
demo accounts to play around with. It will print all accounts and tell you the password.

## Local Phoenix Server

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Enable Machine Learning features and servings

By default the server starts with ML features enabled. To disable running ML features:
  * set `DISABLE_ML_FEATURES` environment variable to true
  * ML dependecies are installed by default. If you wish to not install them run `DISABLE_ML_FEATURES=true mix deps.get`
  * For example to start the phoenix server in dev mode without ML features run `DISABLE_ML_FEATURES=true iex -S mix phx.server`

## Thoughts about the Frontend

Keep it simple. Let's not use JavaScript everywhere. Better ask sw@wintermeyer-consulting.de first 
before diving into a JavaScript driven feature. Use Phoenix tools when possible.

We are doing a mobile first approach and use [Tailwind CSS](https://tailwindui.com). Please don't 
forget a dark mode version when implimenting a new feature.

## Submiting Code

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file.
