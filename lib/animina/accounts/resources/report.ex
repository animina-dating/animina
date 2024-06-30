defmodule Animina.Accounts.Report do
  @moduledoc """
  This is the Report module which we use to manage reports.
  """
  alias Animina.Accounts.BasicUser
  alias Animina.Accounts.User

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: Ash.Policy.Authorizer

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

    read :all_reports do
      prepare build(load: [:accuser, :accused, :admin])

      prepare build(sort: [created_at: :desc])
    end

    read :pending_reports do
      prepare build(load: [:accuser, :accused, :admin])

      prepare build(sort: [created_at: :desc])

      filter expr(state == ^:pending)
    end

    update :review do
      argument :admin_id, :uuid do
        allow_nil? false
      end

      argument :state, :atom do
        constraints one_of: [:accepted, :denied]
        allow_nil? false
      end

      argument :internal_memo, :string do
        constraints max_length: 1_024
        allow_nil? true
      end

      change set_attribute(:admin_id, arg(:admin_id))
      change set_attribute(:state, arg(:state))
      change set_attribute(:internal_memo, arg(:internal_memo))
    end
  end

  code_interface do
    define_for Animina.Accounts
    define :read
    define :create
    define :update
    define :by_id, get_by: [:id], action: :read
    define :all_reports
    define :pending_reports
    define :review
  end

  changes do
    change after_action(fn changeset, record ->
             user = BasicUser.by_id!(record.accused_id)
             User.investigate(user)

             {:ok, record}
           end),
           on: [:create]

    change after_action(fn changeset, record ->
             user = BasicUser.by_id!(record.accused_id)

             change_accused_user_state(user, record.accused_user_state, record.state)

             {:ok, record}
           end),
           on: [:update]
  end

  preparations do
    prepare build(load: [:accuser, :accused, :admin])
  end

  def change_accused_user_state(user, :normal, :accepted) do
    User.ban(user)
  end

  def change_accused_user_state(user, :validated, :accepted) do
    User.ban(user)
  end

  def change_accused_user_state(user, :normal, :denied) do
    User.normalize(user)
  end

  def change_accused_user_state(user, :validated, :denied) do
    User.validate(user)
  end

  def change_accused_user_state(user, _, _) do
    user
  end

  policies do
    policy action_type(:read) do
      authorize_if Animina.Checks.ReadReportCheck
    end

    policy action_type(:update) do
      authorize_if Animina.Checks.UpdateReportCheck
    end
  end

  postgres do
    table "reports"
    repo Animina.Repo
  end
end