# Animina Dating Platform

Animina is a web based dating platform. It is initially targeted at the
German market. In case you have a question do not hesitate to contact
Stefan Wintermeyer <sw@wintermeyer-consulting.de>

Please do submit bug reports or feature requests with an [issue](https://github.com/animina-dating/animina/issues/new).

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

## Local Phoenix Server

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Thoughts about the Frontend

Keep it simple. Let's not use JavaScript everywhere. Better ask sw@wintermeyer-consulting.de first 
before diving into a JavaScript driven feature. Use Phoenix tools when possible.

We are doing a mobile first approach and use [Tailwind CSS](https://tailwindui.com). Please don't 
forget a dark mode version when implimenting a new feature.

## Docker Compose

Alternatively you may want to run the application using Docker-Compose.

&#x26a0;&#xfe0f; For development only. Don't use in production!

On a Mac, please install [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/) first. (Other variants of Docker and Docker-Compose may or may not work.)

Build the images: `docker-compose build`

Run the containers: `docker-compose up`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Submiting Code

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file.
