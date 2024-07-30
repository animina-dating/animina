# ANIMINA Dating Platform

ANIMINA is a web based dating platform. Initially for Germany but ... who knows! 😉 In case you have a question do not hesitate to contact
Stefan Wintermeyer <sw@wintermeyer-consulting.de>

> [!WARNING]  
> The current version a beta version. We appreciate all bug reports!

Please do submit bug reports or feature requests with an [issue](https://github.com/animina-dating/animina/issues/new).

## Setup a dev system

What we assume:

- You have access too a locally hosted [PostgreSQL](https://www.postgresql.org) database.
- You have basic understanding of Elixir and the [Phoenix Framework](https://phoenixframework.org).
- You probably use macOS or Linux.

> [!NOTE]
> Have a look at https://elixir-phoenix-ash.com if you are new to Elixir, Phoenix or Ash.

Here we go:

- Install [asdf](https://asdf-vm.com)
- Git clone the project with `git clone git@github.com:animina-dating/animina.git`
- `cd animina` into the local project clone
- `asdf install` installs the needed Elixir and Erlang versions
- `mix deps.get` or `DISABLE_ML_FEATURES=true mix deps.get` if you wish to not install the ML dependencies
- `cd assets && npm install` to install [Alpine.js](https://alpinejs.dev)
- `mix ash_postgres.create` to create the database
- `mix ash_postgres.migrate` to run migrations
- `mix seed_demo_system` creates dummy accounts and lists them.
- `iex -S mix phx.server` or `DISABLE_ML_FEATURES=true iex -S mix phx.server` if you wish to start the server without ML features

Open http://localhost:4000 in your browser

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


If you want to for example hibernate a user with the username 'wintermeyer' you can run the following in IEX 

`{:ok, user} = Animina.Accounts.User.get_by_username("wintermeyer") `
`Animina.Accounts.User.hibernate(%{user_id: user.id})`



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
