defmodule Animina.Discovery.Schemas.PopularityStat do
  @moduledoc """
  Schema for storing daily popularity statistics and rolling averages.

  Each record represents one user's stats for one day, including:
  - Daily inquiry count (how many new inquiries received that day)
  - 7-day rolling average
  - 30-day rolling average

  Rolling averages are computed by the nightly background worker
  and used for popularity-based scoring adjustments in discovery.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_popularity_stats" do
    belongs_to :user, User

    field :stat_date, :date
    field :daily_inquiry_count, :integer, default: 0
    field :avg_7_day, :float
    field :avg_30_day, :float

    timestamps(type: :utc_datetime)
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:user_id, :stat_date, :daily_inquiry_count, :avg_7_day, :avg_30_day])
    |> validate_required([:user_id, :stat_date, :daily_inquiry_count])
    |> validate_number(:daily_inquiry_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :stat_date])
  end
end
