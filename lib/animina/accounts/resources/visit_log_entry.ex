defmodule Animina.Accounts.VisitLogEntry do
  @moduledoc """
  This is the VisitLogEntry module which we use to manage visit log entries.
  """
  alias Phoenix.PubSub

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer,
    domain: Animina.Accounts,
    extensions: [Ash.Notifier.PubSub]

  attributes do
    uuid_primary_key :id

    attribute :duration, :integer do
      allow_nil? false
    end

    attribute :bookmark_id, :uuid do
      allow_nil? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Animina.Accounts.User do
      domain Animina.Accounts
      allow_nil? false
    end

    belongs_to :bookmark, Animina.Accounts.Bookmark do
      domain Animina.Accounts
      allow_nil? false
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :duration,
        :bookmark_id,
        :user_id
      ]

      primary? true
    end

    update :update do
      accept [:duration, :bookmark_id, :user_id]

      primary? true
      require_atomic? false
    end

    read :by_bookmark_id do
      argument :bookmark_id, :uuid do
        allow_nil? false
      end

      filter expr(bookmark_id == ^arg(:bookmark_id))
    end

    read :by_user_id do
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
    define :update
    define :by_id, get_by: [:id], action: :read
    define :by_bookmark_id, args: [:bookmark_id]
    define :by_user_id, args: [:user_id]
  end

  changes do
    change after_action(fn changeset, record, _context ->
             PubSub.broadcast(
               Animina.PubSub,
               "visit_log_entry:#{record.user_id}",
               {:visit_log_entry, record}
             )

             {:ok, record}
           end),
           on: [:create, :update]
  end

  policies do
    policy action_type(:create) do
      authorize_if Animina.Checks.CreateVisitLogEntryCheck
    end

    policy action_type(:update) do
      authorize_if Animina.Checks.UpdateVisitLogEntryCheck
    end
  end

  postgres do
    table "visit_log_entries"
    repo Animina.Repo

    references do
      reference :bookmark, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:user_id, :bookmark_id]
    end
  end
end
