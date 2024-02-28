#!/bin/bash

set -e

echo "Create the database and run migrations ..."
#mix ecto.setup
mix ash_postgres.create
mix ash_postgres.migrate

echo "Seeding hashtags ..."
mix run priv/repo/flag_seeds.exs || true    #TODO No need to run every time. Should these go into a migration?

echo "Starting application ..."
mix phx.server
#iex -S mix phx.server

