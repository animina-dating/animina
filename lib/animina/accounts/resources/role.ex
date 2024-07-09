defmodule Animina.Accounts.Role do
  @moduledoc """
  This is the Role module which we use to manage roles.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts


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
    defaults [:read]

    create :create do
      accept [

        :name

      ]
      primary? true

    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :by_name, get_by: [:name], action: :read
    define :by_id, get_by: [:id], action: :read
  end

  postgres do
    table "roles"
    repo Animina.Repo
  end
end
