# Animina Dating Platform

## Local Install

### Development Environment

Please install the following tools:

  * [Elixir](https://elixir-lang.org/install.html)
  * [Phoenix](https://hexdocs.pm/phoenix/installation.html)
  * [PostgreSQL](https://www.postgresql.org/download/)
  * [asdf (optional)](https://asdf-vm.com)

Use `asdf install` to install the correct versions of Elixir and Erlang.

### Database Setup

  * Run `mix ecto.setup` to create the database and run migrations
  * Run `mix ecto.reset` to drop the database and run migrations

### Git Hooks

Please run the `./setup-hooks.sh` script to install the git hooks.

### Phoenix Framework

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.


## Docker Compose

Alternatively you may want to run the application using Docker-Compose.

&#x26a0;&#xfe0f; For development only. Don't use in production!

On a Mac, please install [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/) first. (Other variants of Docker and Docker-Compose may or may not work.)

Build the images: `docker-compose build`

Run the containers: `docker-compose up`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.


## Learn more about Phoenix

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
