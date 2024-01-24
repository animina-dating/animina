ARG ELIXIR_VERSION="1.16"
FROM elixir:${ELIXIR_VERSION}
#FROM elixir:${ELIXIR_VERSION}-slim

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive \
  apt-get install -q -y --no-install-recommends --no-install-suggests \
    bash \
    inotify-tools \
    nodejs \
    npm \
    yarn \
    build-essential \
    git \
    postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# Hex, Phoenix
RUN mix local.hex --force
#RUN mix archive.install --force hex phx_new ${PHOENIX_VERSION}
RUN mix local.rebar --force

RUN mkdir -p /application
WORKDIR /application

COPY "./assets"   "./assets"
COPY "./config"   "./config"
COPY "./lib"      "./lib"
COPY "./mix.exs"  "./mix.exs"
COPY "./mix.lock" "./mix.lock"
COPY "./priv"     "./priv"
COPY "./test"     "./test"
COPY "./.formatter.exs"  "./.formatter.exs"
COPY "./.credo.exs"      "./.credo.exs"

RUN mix deps.clean --all
RUN mix deps.get
RUN mix compile

#RUN cd assets && npm install

ARG DATABASE_HOST="db"
ARG DATABASE_PORT="5432"
ARG DATABASE_NAME="animina_dev"
ARG DATABASE_USER="postgres"
ARG DATABASE_PASSWORD="postgres"
RUN echo "${DATABASE_HOST}:${DATABASE_PORT}:${DATABASE_NAME}:${DATABASE_USER}:${DATABASE_PASSWORD}" > ~/.pgpass \
	&& chmod 0600 ~/.pgpass
RUN cat ~/.pgpass

EXPOSE 4000


# For Emacs:
# Local Variables:
# mode: unix-shell-script
# indent-tabs-mode:nil
# tab-width:2
# c-basic-offset:2
# End:
# For VIM:
# vim:set ft=dockerfile softtabstop=2 shiftwidth=2 tabstop=2 expandtab:

