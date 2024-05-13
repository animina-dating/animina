defmodule Animina.Accounts.Bookmark do
  @moduledoc """
  This is the Bookmark module which we use to manage bookmarks.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer,
    extensions: [Ash.Notifier.PubSub]

  attributes do
    uuid_primary_key :id

    attribute :reason, :atom do
      constraints one_of: [:liked, :visited]
      allow_nil? false
    end

    attribute :owner_id, :uuid do
      allow_nil? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :owner, Animina.Accounts.User do
      api Animina.Accounts
      allow_nil? false
    end

    belongs_to :user, Animina.Accounts.User do
      api Animina.Accounts
      allow_nil? false
    end
  end

  pub_sub do
    module Animina
    prefix "bookmark"

    broadcast_type :phoenix_broadcast

    publish :create, ["created", [:owner_id, nil]]
    publish :update, ["updated", :id]
    publish :destroy, ["deleted", [:id]]

    publish_all :destroy, ["deleted", [:owner_id, :id]]
  end

  identities do
    identity :unique_bookmark, [:user_id, :owner_id, :reason]
  end

  actions do
    defaults [:read, :destroy]

    create :like do
      accept [:owner_id, :user_id]
      change set_attribute(:reason, :liked)
    end

    create :visit do
      accept [:owner_id, :user_id]
      change set_attribute(:reason, :visited)
    end

    destroy :unlike do
    end
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :like
    define :unlike
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_owner_and_user_id, get_by: [:owner_id, :user_id], action: :read
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:owner)
    end

    policy action_type(:destroy) do
      authorize_if Animina.Checks.DestroyBookmarkCheck
    end

    # policy action_type(:create) do
    #   authorize_if Animina.Checks.CreateBookmarkCheck
    # end
  end

  postgres do
    table "bookmarks"
    repo Animina.Repo

    references do
      reference :owner, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end
end
