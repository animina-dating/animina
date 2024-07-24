defmodule Animina.Accounts.OptimizedPhoto do
  @moduledoc """
  This is the Optimized Photo module which we use to manage user optimized photos for thumbnail , normal and big.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts

  attributes do
    uuid_primary_key :id
    attribute :image_url, :string, allow_nil?: false

    attribute :type, :atom do
      constraints one_of: [:thumbnail, :normal, :big]

      allow_nil? false
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
  end

  actions do
    defaults [:destroy]

    create :create do
      accept [
        :image_url,
        :type,
        :user_id,
        :photo_id
      ]

      primary? true
    end

    read :read do
      primary? true
      pagination offset?: true, keyset?: true, required?: false
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :destroy
  end

  postgres do
    table "optimized_photos"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
      reference :photo, on_delete: :delete
    end
  end
end
