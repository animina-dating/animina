defmodule Animina.Ads.AdConversion do
  @moduledoc """
  Schema for durable ad conversion records.

  Conversion records survive user deletion (user_id becomes nil via on_delete: :nilify_all)
  so that ad performance metrics remain accurate over time.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ad_conversions" do
    belongs_to :ad, Animina.Ads.Ad
    belongs_to :user, Animina.Accounts.User

    field :converted_at, :utc_datetime
  end

  def changeset(conversion, attrs) do
    conversion
    |> cast(attrs, [:ad_id, :user_id, :converted_at])
    |> validate_required([:ad_id, :converted_at])
    |> foreign_key_constraint(:ad_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:ad_id, :user_id])
  end
end
