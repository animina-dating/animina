# ANIMINA Dating Platform

ANIMINA is a web based dating platform. In case you have a question do not
hesitate to contact Stefan Wintermeyer <sw@wintermeyer-consulting.de>

![Screenshot of a demo ANIMINA profile](https://github.com/animina-dating/animina/blob/main/priv/static/images/profile-screenshot.webp?raw=true)

> [!WARNING]
> The current version a beta version. We appreciate all bug reports!

Please do submit bug reports or feature requests with an [issue](https://github.com/animina-dating/animina/issues/new).

> [!NOTE]
> Project founder Stefan Wintermeyer gave a (German) talk about the first
> ANIMINA Beta at [FrOSCon](https://froscon.org).
>
> - [video recording](https://media.ccc.de/v/froscon2024-3060-parship_tinder_animina_und_co)
> - [slides](https://speakerdeck.com/wintermeyer/disassembling-online-dating-froscon-2024)

## ANIMINA Installation Guide for Developers

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

### Demo Pages

- http://localhost:4000/demo - UX playground showcasing design components
- http://localhost:4000/demo/index2 - German landing page highlighting ANIMINA's differentiators

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

- To remove a user from a waitlist we use `User.give_user_in_waitlist_access` .
  After removing a user from the waitlist, the user will get an email notification that they can now access the platform.
  An example of how to give a user in the waitlist access via CLI is
  `{:ok, user} = Animina.Accounts.User.get_by_username("wintermeyer") `
  `Animina.Accounts.User.give_user_in_waitlist_access(user)`

- To completely delete and remove a usr from the system we use `User.destroy` .
  If you want to for example delete a user with the username 'wintermeyer' you can run the following in IEX

  `{:ok, user} = Animina.Accounts.User.get_by_username("wintermeyer") `
  `Animina.Accounts.User.destroy(user)`

### User Roles

- We have 2 roles `user` and `admin` .
- To make a user an admin , run the following in IEX `Animina.Accounts.User.make_admin(%{user_id: your_user.id})`
- To remove admin roles from a user , run the following in IEX `Animina.Accounts.User.remove_admin(%{user_id: your_user.id})`

## Admin

- There are admin tasks we can do , for example adding points to a user.

### Admin Actions

- Adding 100 Points To A User

`{:ok, user} = Animina.Accounts.User.get_by_username("wintermeyer") `
`user.credit_points`
`Animina.Accounts.Credit.create(%{user_id: user.id, points: 100, subject: "Bonus Points"})`

## Enable Machine Learning features and servings

By default the server starts with ML features enabled. To disable running ML features:

- set `DISABLE_ML_FEATURES` environment variable to true
- ML dependecies are installed by default. If you wish to not install them run `DISABLE_ML_FEATURES=true mix deps.get`
- For example to start the phoenix server in dev mode without ML features run `DISABLE_ML_FEATURES=true iex -S mix phx.server`

## LLM We Use for the AI Features

For development and on our production servers we use [Ollama](https://ollama.com).
So should you on your development system. For development we use the [Llama3.1 (8B)](https://ollama.com/library/llama3.1:8b) LLM. Install Ollama and than run `ollama run llama3.1:8b` to download the needed files for the LLM. You can configure the used LLM in `config/dev.exs` (search for `:llm_version`).

## Swoosh Mailbox Server

To access all the emails sent to the mailbox server, go to `localhost:4000/dev/mailbox` in your browser once the server is running.
Once you register a new account, you can see the email sent to the mailbox server for account verification.

## Thoughts about the Frontend

Keep it simple. Let's not use JavaScript everywhere. Better ask sw@wintermeyer-consulting.de first
before diving into a JavaScript driven feature. Use Phoenix tools when possible.

We are doing a mobile first approach and use [Tailwind CSS](https://tailwindui.com). Please don't
forget a dark mode version when implimenting a new feature.

## Deployment

### Install Kamal

Follow these installation [steps](https://kamal-deploy.org/docs/installation/) to install kamal to your target platform.

### Configure environment variables

Create a .env file in the root of the project and then copy the contents of .env.examnple to it.

To configure the database edit the following env variables
```
POSTGRES_HOST=localhost
POSTGRES_USER=postgres
POSTGRES_PASSWORD=""
POSTGRES_PORT=5432
```

Kamal requires a registry where it can upload and cache the docker containers. This project uses github registry. 
To configure the registry, create a github [token](https://github.com/settings/tokens/new) and grant it the `write:packages` access rights.
Copy the token and paste it in your .env file under the `KAMAL_REGISTRY_PASSWORD` key.
```
KAMAL_REGISTRY_USERNAME=<github-username>
KAMAL_REGISTRY_PASSWORD=<github-token>
```

The rest of the environment variables are similar but prefixed with the target deployment. To cnfigure for prod deployments, edit the variables with
`PROD_` prefix, for dev `DEV_` prefix.

```
*_SERVER_IP=<the-server-ip-where-the-app-will-be-deployed>
*_SECRET_KEY_BASE=<required-by-phoenix> //Use `mix phx.gen.secret 80` to generate this
*_DATABASE_URL=<the-database-connection-string>
*_PHX_HOST=<the-host-url-of-your-app>
*_PORT=<the-host-port-your-app-will-bind-to>
*_FILE_VOLUME_PATH=<the-path-on-the-host-files-will-be-persisted-to>
*_CONTAINER_IMAGE=<the-name-of-the-container-in-the-registry> //Should start with your github username, followed by the container name
```

For example, here's a config for a prod environment
```
PROD_SERVER_IP=127.0.0.1
PROD_SECRET_KEY_BASE=9GGCyEor8pAYi1CncIsZx9opAwhD7+7/zMbrs9NN05/oEH3PXU0AfQ7ESodoXsHg00S07ATBkGKcFbFJ
PROD_DATABASE_URL=ecto://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/animina
PROD_PHX_HOST=animina.de
PROD_PORT=4310
PROD_FILE_VOLUME_PATH=/etc/animina/prod/
PROD_CONTAINER_IMAGE="animina/animina-prod"
```

### Initialize kamal
Run the following command to setup kamal both on your local instance and the remote host. You will be prompted to enter the password
of the remote host. This command will check if Docker is installed and, if not, it will attempt to install it on your host server.

```
kamal server bootstrap
```

### Deploy the application
To deploy the application, run `kamal deploy`. You will need to set the destinations flag `-d` followed by the destination name.
For example to deploy to prod, run
```
kamal deploy -d prod
```
To deploy to dev, run
```
kamal deploy -d dev
```

The above command logins into the docker registry, builds the docker images locally, pushes the build artifacts to the registry and finally deploys the docker images to your host. Read more about `kamal deploy` [here](https://kamal-deploy.org/docs/commands/deploy/)

To redeploy running `kamal deploy` will result in an error as our container is already running and bound to a port on the host. This is due to how kamal 2 works as seen in this github issue [here](https://github.com/basecamp/kamal/issues/1133).

To get around this, first run `kamal app stop` and then run `kamal deploy`. Be sure to specify the destinations using the `-d` flag.


## Submiting Code

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file.
