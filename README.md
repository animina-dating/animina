# ANIMINA Dating Platform

ANIMINA is a web based dating platform. Initially for Germany but ... who knows! 😉 In case you have a question do not hesitate to contact
Stefan Wintermeyer <sw@wintermeyer-consulting.de>

> [!WARNING]
> The current version a beta version. We appreciate all bug reports!

Please do submit bug reports or feature requests with an [issue](https://github.com/animina-dating/animina/issues/new).

> [!TIP]
> Project founder Stefan Wintermeyer will give a talk about ANIMINA and other 
> dating platforms at [FrOSCon](https://froscon.org). First slot on August the 18th 2024. 
> See you there!

## ANIMINA Installation Guide

What we assume:

- macOS or Linux as an OS
- Installed [PostgreSQL](https://www.postgresql.org) database.
- Basic understanding of Elixir and the [Phoenix Framework](https://phoenixframework.org). Have a look at https://elixir-phoenix-ash.com if you are new to it.

> [!IMPORTANT]
> If you wish to disable ML features (e.g., because of slow hardware), add `DISABLE_ML_FEATURES=true` before `mix` and `iex` commands.

### Install Dependencies

We use [asdf](https://asdf-vm.com) to handle the Elixir and Erlang version. You don't have to use it but in our opinion it is the best solution.

- Install asdf ([Get started guide](https://asdf-vm.com/guide/getting-started.html))
  - `asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git`
  - `asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git`
  - `asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git`

### Clone the Project

- Git clone the project with `git clone git@github.com:animina-dating/animina.git`
- `cd animina` into the local project clone

### Set Up the Environment

- `asdf install` installs the needed Elixir and Erlang versions

### Install Dependencies

- `mix deps.get`
- `cd assets && npm install` to install [Alpine.js](https://alpinejs.dev)
- `cd ..`

### Database Setup

- `mix ash_postgres.create` to create the database
- `mix ash_postgres.migrate` to run migrations

### Seed the Database

This step is optional, but very useful for development and demo systems.

- `mix seed_demo_system` creates dummy accounts and lists them.

### Start the Server

- `iex -S mix phx.server`

### GO!

Open http://localhost:4000 in your browser. You can create a new profile and visit the demo accounts. And you can log into the demo accounts. The default password of the demo accounts is printed at the end of the list of demo accounts after running `mix seed_demo_system`.

## User

The `User` resource is the center of the system. In the very beginning of the registration process we also use `BasicUser`.

### User States

The following user states change their visibility across the system:

- `normal` - Standard account.
- `validated` - This is a validated account, indicating that we are confident it belongs to a real person.
- `under_investigation` - This account has been flagged by another user, an admin, or an AI for suspicious activity. They cannot log in.
- `banned` - This account is banned. We retain it to block the associated mobile phone number and email address. They cannot log in.
- `incognito` The user prefers to browse without being seen.
- `hibernate`- The user wishes to keep the account but is not currently using it.
- `archived`- The account has been deleted by the user. They cannot log in.

### User Actions

To change the state of a user account use the following actions:

- `User.validate` - This action is used to validate an account.
- `User.investigate` - This action is used to flag an account for investigation.
- `User.ban` - This action is used to ban an account.
- `User.incognito` - This action is used to set an account to incognito.
- `User.hibernate` - This action is used to set an account to hibernate.
- `User.archive` - This action is used to archive an account
- `User.reactivate` - This action is used to reactivate an account
- `User.normalize` - This action is used to set an account to normal.
- `User.unban` - This action is used to unban an account.
- `User.recover` - This action is used to recover an account from incognito or hibernate.

### User Roles

- We have 2 roles `user` and `admin` .
- To make a user an admin , run the following in IEX `Animina.Accounts.User.make_admin(%{user_id: your_user.id})`
- To remove admin roles from a user , run the following in IEX `Animina.Accounts.User.remove_admin(%{user_id: your_user.id})`

## Enable Machine Learning features and servings

By default the server starts with ML features enabled. To disable running ML features:
  * set `DISABLE_ML_FEATURES` environment variable to true
  * ML dependecies are installed by default. If you wish to not install them run `DISABLE_ML_FEATURES=true mix deps.get`
  * For example to start the phoenix server in dev mode without ML features run `DISABLE_ML_FEATURES=true iex -S mix phx.server`

## Swoosh Mailbox Server

Use `iex -S mix swoosh.mailbox.server` to start the Swoosh Mailbox Server webpage in development. Go to http://localhost:4000 so see the mailbox.

## Thoughts about the Frontend

Keep it simple. Let's not use JavaScript everywhere. Better ask sw@wintermeyer-consulting.de first 
before diving into a JavaScript driven feature. Use Phoenix tools when possible.

We are doing a mobile first approach and use [Tailwind CSS](https://tailwindui.com). Please don't 
forget a dark mode version when implimenting a new feature.

## Submiting Code

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file.
