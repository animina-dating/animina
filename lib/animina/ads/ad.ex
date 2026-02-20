defmodule Animina.Ads.Ad do
  @moduledoc """
  Schema for ad campaigns with trackable URLs and QR codes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.TimeMachine

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ads" do
    field :number, :integer
    field :url, :string
    field :description, :string
    field :starts_on, :date
    field :ends_on, :date
    field :qr_code_path, :string

    has_many :visits, Animina.Ads.AdVisit, foreign_key: :ad_id
    has_many :conversions, Animina.Ads.AdConversion, foreign_key: :ad_id

    timestamps(type: :utc_datetime)
  end

  def changeset(ad, attrs) do
    ad
    |> cast(attrs, [:number, :url, :description, :starts_on, :ends_on, :qr_code_path])
    |> validate_required([:number, :url])
    |> unique_constraint(:number)
    |> unique_constraint(:url)
    |> validate_date_range()
    |> check_constraint(:starts_on, name: :starts_on_before_ends_on)
  end

  def update_changeset(ad, attrs) do
    ad
    |> cast(attrs, [:description, :starts_on, :ends_on])
    |> validate_date_range()
    |> check_constraint(:starts_on, name: :starts_on_before_ends_on)
  end

  defp validate_date_range(changeset) do
    starts_on = get_field(changeset, :starts_on)
    ends_on = get_field(changeset, :ends_on)

    if starts_on && ends_on && Date.compare(starts_on, ends_on) == :gt do
      add_error(changeset, :starts_on, "must be on or before end date")
    else
      changeset
    end
  end

  @doc """
  Returns true if the ad is currently active based on its date range.
  An ad with no dates is always active.
  """
  def active?(%__MODULE__{starts_on: nil, ends_on: nil}), do: true

  def active?(%__MODULE__{starts_on: starts_on, ends_on: nil}) do
    Date.compare(TimeMachine.utc_today(), starts_on) != :lt
  end

  def active?(%__MODULE__{starts_on: nil, ends_on: ends_on}) do
    Date.compare(TimeMachine.utc_today(), ends_on) != :gt
  end

  def active?(%__MODULE__{starts_on: starts_on, ends_on: ends_on}) do
    today = TimeMachine.utc_today()
    Date.compare(today, starts_on) != :lt and Date.compare(today, ends_on) != :gt
  end

  @doc """
  Returns the base36-encoded short code for the ad number.
  """
  def short_code(%__MODULE__{number: number}),
    do: Integer.to_string(number, 36) |> String.downcase()
end
