defmodule Animina.Accounts.VisitLogEntry do
  @moduledoc """
  This is the VisitLogEntry module which we use to manage visit log entries.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer

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
      api Animina.Accounts
      allow_nil? false
    end

    belongs_to :bookmark, Animina.Accounts.Bookmark do
      api Animina.Accounts
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update]
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
    define :update
    define :by_id, get_by: [:id], action: :read
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
