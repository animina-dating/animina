defmodule Animina.Accounts.UserRole do
  @moduledoc """
  This is the User Role module which we use to manage user roles.
  """
  alias Animina.Accounts.User
  alias Phoenix.PubSub

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts,
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
    defaults [:read, :destroy]

    create :create do
      accept [
        :user_id,
        :role_id
      ]

      primary? true
    end

    read :by_user_id do
      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:role])
      filter expr(user_id == ^arg(:user_id))
    end

    read :admin_roles_by_user_id do
      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:role])
      filter expr(user_id == ^arg(:user_id) and role.name == :admin)
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :destroy
    define :by_user_id, args: [:user_id]
    define :admin_roles_by_user_id
  end

  changes do
    change after_action(fn changeset, record, _context ->
             PubSub.broadcast(
               Animina.PubSub,
               record.user_id,
               {:user, User.by_id!(record.user_id)}
             )

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
