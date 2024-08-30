defmodule Animina.Accounts.PotentialPartner do
  @moduledoc """
  This is the PotentialPartner module which we use to manage potential partners.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts,
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
      domain Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :potential_partner, Animina.Accounts.User do
      domain Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_potential_partner, [:user_id, :potential_partner_id]
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :user_id,
        :potential_partner_id
      ]

      primary? true
    end

    read :potential_partners_for_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:potential_partner])
      prepare build(sort: [position: :desc])

      filter expr(user_id == ^arg(:user_id))
    end

    read :active_potential_partners_for_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:potential_partner])
      prepare build(sort: [position: :asc])

      filter expr(user_id == ^arg(:user_id) and is_active == true)
    end

    read :four_active_potential_partners_for_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      pagination offset?: true, default_limit: 4

      prepare build(load: [:potential_partner])
      prepare build(sort: [position: :asc])

      filter expr(user_id == ^arg(:user_id) and is_active == true)
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :potential_partners_for_user, args: [:user_id]
    define :active_potential_partners_for_user, args: [:user_id]
    define :four_active_potential_partners_for_user, args: [:user_id]
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
