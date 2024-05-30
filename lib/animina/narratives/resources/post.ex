defmodule Animina.Narratives.Post do
  @moduledoc """
  This is the post resource.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      constraints max_length: 8192
      allow_nil? false
    end

    attribute :slug, :string, allow_nil?: false
    attribute :title, :string, allow_nil?: false

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  pub_sub do
    module Animina
    prefix "post"

    broadcast_type :phoenix_broadcast

    publish :create, ["created", [:user_id, nil]]
    publish :update, ["updated", :id]
    publish :destroy, ["deleted", [:id]]

    publish_all :destroy, ["deleted", [:user_id, :id]]
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
    end
  end

  validations do
    validate present(:slug)
  end

  actions do
    defaults [:create, :update, :destroy]

    read :read do
      primary? true
      pagination offset?: true, keyset?: true, required?: false

      # prepare build(load: [:headline, :photo])
    end

    read :by_user_id do
      pagination offset?: true, keyset?: true, required?: false

      argument :user_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:user])

      filter expr(user_id == ^arg(:user_id))
    end
  end

  code_interface do
    define_for Animina.Narratives
    define :read
    define :create
    define :update
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_user_id, args: [:user_id]
  end

  postgres do
    table "posts"
    repo Animina.Repo

    custom_indexes do
      index [:user_id]
    end

    references do
      reference :user, on_delete: :delete
    end
  end
end
