defmodule Animina.Analytics.DailyFunnelStat do
  @moduledoc """
  Schema for daily funnel metric rollups.

  One row per day tracking the conversion funnel:
  visitors → registered → profile_completed → first_message → mutual_match.
  Kept indefinitely for historical reporting.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "daily_funnel_stats" do
    field :date, :date
    field :visitors, :integer, default: 0
    field :registered, :integer, default: 0
    field :profile_completed, :integer, default: 0
    field :first_message, :integer, default: 0
    field :mutual_match, :integer, default: 0
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:date, :visitors, :registered, :profile_completed, :first_message, :mutual_match])
    |> validate_required([:date])
    |> unique_constraint([:date])
  end
end
