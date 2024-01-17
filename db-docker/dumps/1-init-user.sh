#!/bin/bash
set -e

echo "--------------------------"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE USER "animina";
	/*
	CREATE DATABASE "animina_dev";
	GRANT ALL PRIVILEGES ON DATABASE "animina_dev" TO "animina";
	*/
EOSQL

echo "--------------------------"

