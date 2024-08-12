defmodule Animina.Accounts.Report do
  @moduledoc """
  This is the Report module which we use to manage reports.
  """

  alias Animina.Accounts.User
  alias Animina.UserEmail

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Animina.Accounts,
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
      domain Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :accuser, Animina.Accounts.User do
      domain Animina.Accounts
      attribute_writable? true
      allow_nil? false
    end

    belongs_to :admin, Animina.Accounts.User do
      domain Animina.Accounts
      attribute_writable? true
      allow_nil? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :state,
        :accused_id,
        :accuser_id,
        :description,
        :accused_user_state,
        :admin_id,
        :internal_memo
      ]

      primary? true
    end

    read :all_reports do
      prepare build(load: [:accuser, :accused, :admin])

      prepare build(sort: [created_at: :desc])
    end

    read :pending_reports do
      prepare build(load: [:accuser, :accused, :admin])

      prepare build(sort: [created_at: :desc])

      filter expr(state == ^:pending)
    end

    update :update do
      accept [
        :state,
        :accused_id,
        :accuser_id,
        :description,
        :accused_user_state,
        :admin_id,
        :internal_memo
      ]

      primary? true
      require_atomic? false
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

      require_atomic? false

      change set_attribute(:admin_id, arg(:admin_id))
      change set_attribute(:state, arg(:state))
      change set_attribute(:internal_memo, arg(:internal_memo))
    end
  end

  code_interface do
    domain Animina.Accounts
    define :read
    define :create
    define :update
    define :by_id, get_by: [:id], action: :read
    define :all_reports
    define :pending_reports
    define :review
  end

  changes do
    change after_action(fn changeset, record, _context ->
             user = User.by_id!(record.accused_id)
             User.investigate(user)

             send_notification_email_to_admin(record.id, record.description)

             {:ok, record}
           end),
           on: [:create]

    change after_action(fn changeset, record, _context ->
             user = User.by_id!(record.accused_id)

             change_accused_user_state(user, record.accused_user_state, record.state)

             {:ok, record}
           end),
           on: [:update]
  end

  preparations do
    prepare build(load: [:accuser, :accused, :admin])
  end

  defp send_notification_email_to_admin(id, description) do
    UserEmail.send_email(
      "Stefan Wintermeyer",
      "stefan@wintermeyer.de",
      "New Report on Animina",
      "Hi Stefan\n\nA new report has been submitted on Animina. The description is \n\n-- \n #{description} \n\n-- \nYou can review the report on https://animina.de/admin/reports/pending/#{id}/review"
    )
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
