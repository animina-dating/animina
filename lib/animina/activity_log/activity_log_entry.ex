defmodule Animina.ActivityLog.ActivityLogEntry do
  @moduledoc """
  Schema for unified activity log entries.

  Each entry records who did what to whom, with a category, event type,
  optional metadata, and a pre-formatted summary string for the admin UI.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.TimeMachine

  @valid_categories ~w(auth social profile admin system)

  @events_by_category %{
    "auth" =>
      ~w(login_email login_passkey login_failed logout session_created session_destroyed sudo_mode),
    "social" =>
      ~w(profile_visit message_sent conversation_created conversation_closed conversation_blocked conversation_reopened bookmark_added reaction_added dismissal_created report_filed report_appeal_filed relationship_proposed relationship_accepted relationship_declined relationship_changed),
    "profile" =>
      ~w(profile_updated flags_changed moodboard_changed preferences_changed location_changed avatar_changed email_changed password_changed passkey_registered passkey_deleted account_registered account_deleted account_reactivated registration_step_completed referral_waitlist_reduced tos_accepted),
    "admin" =>
      ~w(role_granted role_revoked feature_flag_toggled photo_review_approved photo_review_rejected photo_review_retry photo_description_regenerated blacklist_entry_added blacklist_entry_removed report_resolved report_appeal_resolved user_warned user_suspended user_banned user_unsuspended karen_auto_reported ad_created ad_updated),
    "system" =>
      ~w(photo_uploaded photo_approved photo_rejected photo_processing photo_description_generated email_sent email_bounced ollama_processed account_expired)
  }

  @valid_events @events_by_category |> Map.values() |> List.flatten()

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "activity_logs" do
    belongs_to :actor, User
    belongs_to :subject, User

    field :category, :string
    field :event, :string
    field :metadata, :map, default: %{}
    field :summary, :string

    field :inserted_at, :utc_datetime
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:actor_id, :subject_id, :category, :event, :metadata, :summary])
    |> validate_required([:category, :event, :summary])
    |> validate_inclusion(:category, @valid_categories)
    |> validate_inclusion(:event, @valid_events)
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    if changeset.valid? && is_nil(get_field(changeset, :inserted_at)) do
      put_change(changeset, :inserted_at, TimeMachine.utc_now(:second))
    else
      changeset
    end
  end

  @doc """
  Returns the list of valid categories.
  """
  def valid_categories, do: @valid_categories

  @doc """
  Returns the list of all valid events.
  """
  def valid_events, do: @valid_events

  @doc """
  Returns valid events for a given category.
  """
  def events_for_category(category) when is_binary(category) do
    Map.get(@events_by_category, category, [])
  end
end
