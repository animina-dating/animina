defmodule Animina.Reports.Report do
  @moduledoc """
  Schema for user reports.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.Reports.Category

  @valid_categories Category.keys()
  @valid_statuses ~w(pending under_review resolved)
  @valid_resolutions ~w(warning temp_ban_3 temp_ban_7 temp_ban_30 permanent_ban dismissed)
  @valid_priorities ~w(critical high medium low)
  @valid_context_types ~w(chat moodboard profile)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_reports" do
    belongs_to :reporter, User
    belongs_to :reported_user, User
    belongs_to :resolver, User

    has_one :evidence, Animina.Reports.ReportEvidence, foreign_key: :report_id
    has_one :appeal, Animina.Reports.ReportAppeal, foreign_key: :report_id

    field :reporter_phone_hash, :string
    field :reported_phone_hash, :string
    field :category, :string
    field :description, :string
    field :context_type, :string
    field :context_reference_id, :binary_id
    field :status, :string, default: "pending"
    field :resolution, :string
    field :resolution_notes, :string
    field :priority, :string
    field :resolved_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :reporter_id,
      :reported_user_id,
      :reporter_phone_hash,
      :reported_phone_hash,
      :category,
      :description,
      :context_type,
      :context_reference_id,
      :status,
      :resolution,
      :resolution_notes,
      :priority,
      :resolver_id,
      :resolved_at
    ])
    |> validate_required([
      :reported_phone_hash,
      :reporter_phone_hash,
      :category,
      :context_type,
      :status,
      :priority
    ])
    |> validate_inclusion(:category, @valid_categories)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:context_type, @valid_context_types)
    |> validate_inclusion(:priority, @valid_priorities)
    |> validate_length(:description, max: 500)
    |> foreign_key_constraint(:reporter_id)
    |> foreign_key_constraint(:reported_user_id)
    |> foreign_key_constraint(:resolver_id)
  end

  def resolve_changeset(report, attrs) do
    report
    |> cast(attrs, [:status, :resolution, :resolution_notes, :resolver_id, :resolved_at])
    |> validate_required([:status, :resolution, :resolver_id, :resolved_at])
    |> validate_inclusion(:resolution, @valid_resolutions)
    |> put_change(:status, "resolved")
  end

  @doc "Returns the display label for a resolution (for admin UI)."
  def resolution_label("warning"), do: "Warning"
  def resolution_label("temp_ban_" <> days), do: "#{days}-day ban"
  def resolution_label("permanent_ban"), do: "Permanent ban"
  def resolution_label("dismissed"), do: "Dismissed"
  def resolution_label(other), do: other

  def valid_categories, do: @valid_categories
  def valid_resolutions, do: @valid_resolutions
  def valid_priorities, do: @valid_priorities
  def valid_context_types, do: @valid_context_types
end
