defmodule Animina.Accounts.OptimizedPhoto do
  @moduledoc """
  This is the Optimized Photo module which we use to manage user optimized photos for thumbnail , normal and big.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts

  postgres do
    table "optimized_photos"
    repo Animina.Repo

    references do
      reference :user, on_delete: :delete
      reference :photo, on_delete: :delete
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :destroy
    define :by_type_and_photo_id, get?: true
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

    read :by_type_and_photo_id do
      argument :type, :atom do
        allow_nil? false
      end

      argument :photo_id, :uuid do
        allow_nil? false
      end

      pagination offset?: true, keyset?: true, required?: false

      filter expr(type == ^arg(:type) and photo_id == ^arg(:photo_id))
    end
  end

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
end
