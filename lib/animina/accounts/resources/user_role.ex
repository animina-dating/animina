defmodule Animina.Accounts.UserRole do
  @moduledoc """
  This is the User Role module which we use to manage user roles.
  """

  alias Animina.Accounts.User
  alias Phoenix.PubSub

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer

  attributes do
    uuid_primary_key :id

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :role, Animina.Accounts.Role do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read]

    read :by_user_id do
      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:role])
      filter expr(user_id == ^arg(:user_id))
    end
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
    define :by_user_id, args: [:user_id]
  end

  changes do
    change after_action(fn changeset, record ->
             username =
               User.by_id!(record.user_id)
               |> Map.get(:username)
               |> Ash.CiString.value()

             PubSub.broadcast(Animina.PubSub, username, {:user, User.by_id!(record.user_id)})

             {:ok, record}
           end),
           on: [:create]
  end

  preparations do
    prepare build(load: [:role])
  end

  policies do
    policy action(:create) do
      authorize_if Animina.Checks.CreateUserRoleCheck
    end

    policy action(:read) do
      authorize_if Animina.Checks.ReadUserRoleCheck
    end
  end

  postgres do
    table "user_roles"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
      reference :role, on_delete: :delete
    end
  end
end
