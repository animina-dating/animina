defmodule Animina.Emails.EmailLog do
  @moduledoc """
  Schema for logging all emails sent by the system.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @email_types ~w(
    confirmation_pin
    password_reset
    update_email
    duplicate_registration
    account_deletion_goodbye
    daily_report
    registration_spike_alert
    ollama_queue_alert
    unread_messages
    email_changed_notification
    password_changed_notification
  )

  schema "email_logs" do
    belongs_to :user, User

    field :email_type, :string
    field :recipient, :string
    field :subject, :string
    field :body, :string
    field :status, :string
    field :error_message, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(email_log, attrs) do
    email_log
    |> cast(attrs, [:user_id, :email_type, :recipient, :subject, :body, :status, :error_message])
    |> validate_required([:email_type, :recipient, :subject, :body, :status])
    |> validate_inclusion(:status, ["sent", "error"])
    |> validate_inclusion(:email_type, @email_types)
    |> foreign_key_constraint(:user_id)
  end

  def email_types, do: @email_types
end
