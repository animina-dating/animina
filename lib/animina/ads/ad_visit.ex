defmodule Animina.Ads.AdVisit do
  @moduledoc """
  Schema for ad visit tracking (append-only log).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ad_visits" do
    belongs_to :ad, Animina.Ads.Ad

    field :ip_address, :string
    field :user_agent, :string
    field :referer, :string
    field :os, :string
    field :browser, :string
    field :device_type, :string
    field :device_model, :string
    field :language, :string
    field :is_bot, :boolean, default: false
    field :visited_at, :utc_datetime
  end

  @fields [
    :ad_id,
    :ip_address,
    :user_agent,
    :referer,
    :os,
    :browser,
    :device_type,
    :device_model,
    :language,
    :is_bot,
    :visited_at
  ]

  def changeset(visit, attrs) do
    visit
    |> cast(attrs, @fields)
    |> validate_required([:ad_id, :visited_at])
    |> truncate_string(:user_agent, 500)
    |> truncate_string(:referer, 500)
    |> foreign_key_constraint(:ad_id)
  end

  defp truncate_string(changeset, field, max_length) do
    case get_change(changeset, field) do
      nil ->
        changeset

      value when is_binary(value) and byte_size(value) > max_length ->
        put_change(changeset, field, String.slice(value, 0, max_length))

      _ ->
        changeset
    end
  end
end
