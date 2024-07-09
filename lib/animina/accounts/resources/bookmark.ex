defmodule Animina.Accounts.Bookmark do
  @moduledoc """
  This is the Bookmark module which we use to manage bookmarks.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer,
    domain: Animina.Accounts,
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

    attribute :last_visit_at, :utc_datetime

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :owner, Animina.Accounts.User do
      domain Animina.Accounts
      allow_nil? false
    end

    belongs_to :user, Animina.Accounts.User do
      domain Animina.Accounts
      allow_nil? false
    end

    has_many :visit_log_entries, Animina.Accounts.VisitLogEntry
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
    defaults [:destroy]

    read :read do
      primary? true
      pagination offset?: true, keyset?: true, required?: false
    end

    update :update_last_visit do
      argument :last_visit_at, :utc_datetime do
        allow_nil? false
      end

      change set_attribute(:last_visit_at, arg(:last_visit_at))
    end

    read :most_often_visited_by_user do
      argument :owner_id, :uuid do
        allow_nil? false
      end

      pagination offset?: true, default_limit: 10

      prepare build(load: [:visit_log_entries_total_duration, :visit_log_entries_count, :user])

      prepare build(sort: [visit_log_entries_count: :desc])

      filter expr(owner_id == ^arg(:owner_id) and reason == :visited)
    end

    read :longest_overall_duration_visited_by_user do
      argument :owner_id, :uuid do
        allow_nil? false
      end

      prepare build(sort: [visit_log_entries_total_duration: :desc])
      pagination offset?: true, default_limit: 10

      filter expr(owner_id == ^arg(:owner_id) and reason == :visited)
    end

    read :by_reason do
      argument :owner_id, :uuid do
        allow_nil? false
      end

      argument :reason, :atom do
        allow_nil? false
      end

      prepare build(load: [:user])

      prepare build(sort: [created_at: :desc])

      filter expr(owner_id == ^arg(:owner_id) and reason == ^arg(:reason))

      pagination offset?: true, keyset?: true, required?: false
    end

    create :like do
      accept [:owner_id, :user_id]
      change set_attribute(:reason, :liked)
    end

    create :visit do
      accept [:owner_id, :user_id, :last_visit_at]
      change set_attribute(:reason, :visited)
    end

    destroy :unlike do
    end

    read :by_owner do
      argument :owner_id, :uuid do
        allow_nil? false
      end

      prepare build(load: [:user])

      filter expr(owner_id == ^arg(:owner_id))
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :like
    define :visit
    define :unlike
    define :update_last_visit
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_owner_user_and_reason, get_by: [:owner_id, :user_id, :reason], action: :read
    define :by_owner, args: [:owner_id]
    define :most_often_visited_by_user, args: [:owner_id]
    define :longest_overall_duration_visited_by_user, args: [:owner_id]
  end

  aggregates do
    sum :visit_log_entries_total_duration, :visit_log_entries, :duration
    count :visit_log_entries_count, :visit_log_entries
  end

  preparations do
    prepare build(load: [:visit_log_entries_total_duration, :visit_log_entries_count, :user])
  end

  policies do
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via(:owner)
    end

    policy action_type(:destroy) do
      authorize_if Animina.Checks.DestroyBookmarkCheck
    end
  end

  postgres do
    table "bookmarks"
    repo Animina.Repo

    references do
      reference :owner, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:owner_id]
      index [:reason]
      index [:user_id]
      index [:owner_id, :user_id]
      index [:owner_id, :reason]
    end
  end
end
