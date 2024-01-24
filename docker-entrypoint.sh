#!/bin/bash

set -e

echo "Create the database and run migrations ..."
#mix ecto.setup
mix ash_postgres.create
mix ash_postgres.migrate

echo "Starting application ..."
mix phx.server
#iex -S mix phx.server

