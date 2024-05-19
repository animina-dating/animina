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

    attribute :last_visit_at, :utc_datetime

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

    has_many :visit_log_entries, Animina.Accounts.VisitLogEntry do
      destination_attribute :user_id
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
      argument :user_id, :uuid do
        allow_nil? false
      end

      pagination offset?: true, default_limit: 10

      filter expr(owner_id == ^arg(:user_id) and reason == :visited)
    end

    read :longest_overall_duration_visited_by_user do
      argument :user_id, :uuid do
        allow_nil? false
      end

      pagination offset?: true, default_limit: 10

      filter expr(owner_id == ^arg(:user_id) and reason == :visited)
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
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :like
    define :visit
    define :unlike
    define :update_last_visit
    define :destroy
    define :by_id, get_by: [:id], action: :read
    define :by_owner_user_and_reason, get_by: [:owner_id, :user_id, :reason], action: :read
    define :most_often_visited_by_user, args: [:user_id]
    define :longest_overall_duration_visited_by_user, args: [:user_id]
  end

  calculations do
    calculate :visit_log_entries_count,
              :integer,
              {Animina.Calculations.VisitLogEntriesCount, field: :id}

    calculate :visit_log_entries_total_duration,
              :integer,
              {Animina.Calculations.VisitLogEntriesTotalDuration, field: :id}
  end

  preparations do
    prepare build(load: [:visit_log_entries_count, :visit_log_entries_total_duration, :user])
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
