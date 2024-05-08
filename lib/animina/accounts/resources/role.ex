defmodule Animina.Accounts.Role do
  @moduledoc """
  This is the Role module which we use to manage roles.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :name, :atom do
      constraints one_of: [:user, :admin]
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:create, :read]
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
  end

  postgres do
    table "roles"
    repo Animina.Repo
  end
end
