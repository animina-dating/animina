defmodule Animina.Accounts.PhotoFlags do
  @moduledoc """
  This is the Photo module which we use to manage user photos.
  """

  require Logger

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts

  attributes do
    uuid_primary_key :id

    attribute :description, :string do
      constraints max_length: 1_024
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :photo, Animina.Accounts.Photo do
      domain Animina.Accounts
      attribute_writable? true
    end

    belongs_to :flag, Animina.Traits.Flag do
      domain Animina.Traits
      attribute_writable? true
    end
  end

  actions do
    defaults [:destroy]

    create :create do
      accept [
        :user_id,
        :photo_id,
        :flag_id,
        :description
      ]

      primary? true
    end

    read :read do
      primary? true
      pagination offset?: true, keyset?: true, required?: false
    end

    read :by_user_id do
      pagination offset?: true, keyset?: true, required?: false

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :by_id, get_by: [:id], action: :read
    define :destroy
    define :by_user_id, args: [:user_id]
  end

  postgres do
    table "photo_flags"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
      reference :photo, on_delete: :delete
      reference :flag, on_delete: :delete
    end
  end
end
