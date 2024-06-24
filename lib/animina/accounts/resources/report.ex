defmodule Animina.Accounts.Report do
  @moduledoc """
  This is the Report module which we use to manage reports.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :state, :atom do
      constraints one_of: [:pending, :under_review, :accepted, :denied]
      allow_nil? false
    end

    attribute :accused_user_state, :atom do
      constraints one_of: [
                    :normal,
                    :validated,
                    :under_investigation,
                    :banned,
                    :incognito,
                    :hibernate,
                    :archived
                  ]

      allow_nil? false
    end

    attribute :description, :string do
      constraints max_length: 1_024
      allow_nil? false
    end

    attribute :internal_memo, :string do
      constraints max_length: 1_024
      allow_nil? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :accused, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :accuser, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :admin, Animina.Accounts.User do
      api Animina.Accounts
      attribute_writable? true
      allow_nil? true
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
  end

  postgres do
    table "reports"
    repo Animina.Repo
  end
end
