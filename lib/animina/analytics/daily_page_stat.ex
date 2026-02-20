defmodule Animina.Analytics.DailyPageStat do
  @moduledoc """
  Schema for daily page view rollups.

  One row per path per day, aggregated from raw `PageView` records.
  Kept indefinitely for historical reporting.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "daily_page_stats" do
    field :date, :date
    field :path, :string
    field :view_count, :integer, default: 0
    field :unique_sessions, :integer, default: 0
    field :unique_users, :integer, default: 0
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:date, :path, :view_count, :unique_sessions, :unique_users])
    |> validate_required([:date, :path])
    |> unique_constraint([:date, :path])
  end
end
