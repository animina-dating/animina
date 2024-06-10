defmodule Animina.Accounts.PotentialPartner do
  alias Animina.Accounts.User
  alias Phoenix.PubSub

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer

  attributes do
    uuid_primary_key :id

    attribute :is_active, :boolean do
      allow_nil? false
      default true
    end

    attribute :position, :integer do
      allow_nil? false
      generated? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :potential_partner, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_potential_partner, [:user_id, :potential_partner_id]
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
    table "potential_partners"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
      reference :potential_partner, on_delete: :delete
    end

    custom_indexes do
      index [:user_id]

      index [:user_id, :potential_partner_id]
    end
  end
end
