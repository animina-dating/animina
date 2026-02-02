defmodule Animina.Accounts.OnlineUserCount do
  @moduledoc """
  Schema for recording periodic snapshots of online user counts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "online_user_counts" do
    field :count, :integer
    field :recorded_at, :utc_datetime
  end

  def changeset(online_user_count, attrs) do
    online_user_count
    |> cast(attrs, [:count, :recorded_at])
    |> validate_required([:count, :recorded_at])
  end
end
