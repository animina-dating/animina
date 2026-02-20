defmodule Animina.Analytics.PageView do
  @moduledoc """
  Schema for raw page view events.

  Each record represents a single page view. Records are purged
  after 90 days; aggregated data lives in `DailyPageStat`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.TimeMachine

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "page_views" do
    belongs_to :user, User
    field :session_id, :string
    field :path, :string
    field :referrer_path, :string
    field :inserted_at, :utc_datetime
  end

  def changeset(page_view, attrs) do
    page_view
    |> cast(attrs, [:user_id, :session_id, :path, :referrer_path])
    |> validate_required([:session_id, :path])
    |> foreign_key_constraint(:user_id)
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    if changeset.valid? && is_nil(get_field(changeset, :inserted_at)) do
      put_change(changeset, :inserted_at, TimeMachine.utc_now(:second))
    else
      changeset
    end
  end
end
