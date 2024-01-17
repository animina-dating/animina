#!/bin/bash

set -e

echo "Create the database and run migrations ..."
mix ecto.setup

echo "Starting application ..."
mix phx.server
#iex -S mix phx.server

