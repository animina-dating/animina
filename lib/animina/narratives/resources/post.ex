defmodule Animina.Narratives.Post do
  @moduledoc """
  This is the post resource.
  """

  alias Animina.Calculations
  alias Animina.Changes

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    authorizers: Ash.Policy.Authorizer

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
    belongs_to :user, Animina.Accounts.BasicUser do
      api Animina.Accounts
      attribute_writable? true
    end
  end

  validations do
    validate present(:content)
    validate present(:title)
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
    define :by_slug, get_by: [:slug], action: :read
    define :by_user_id, args: [:user_id]
  end

  changes do
    change {Changes.PostSlug, attribute: :title}, on: [:create, :update]
  end

  calculations do
    calculate :url, :string, {Calculations.PostUrl, field: :slug}
  end

  preparations do
    prepare build(
              load: [
                :user,
                :url
              ]
            )
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:update) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:user)
    end
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
