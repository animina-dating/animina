defmodule Animina.Narratives.Story do
  @moduledoc """
  This is the story resource.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :content, :string
    attribute :position, :integer, allow_nil?: false
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
    end

    belongs_to :headline, Animina.Narratives.Headline do
      attribute_writable? true
    end

    has_one :photo, Animina.Accounts.Photo do
      api Animina.Accounts
    end
  end

  actions do
    defaults [:create, :update, :destroy]

    read :read do
      primary? true
      pagination offset?: true, keyset?: true, required?: false
    end

    read :by_user_id do
      pagination offset?: true, keyset?: true, required?: false

      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(sort: [position: :asc])

      filter expr(user_id == ^arg(:user_id))
    end

    read :user_headlines do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(is_nil(headline_id) == ^false and user_id == ^arg(:user_id))
    end
  end

  code_interface do
    define_for Animina.Narratives
    define :read
    define :create
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
  end

  identities do
    identity :unique_position, [:position, :user_id]
  end

  preparations do
    prepare build(load: [:headline, :photo, :user])
  end

  postgres do
    table "stories"
    repo Animina.Repo
  end
end
