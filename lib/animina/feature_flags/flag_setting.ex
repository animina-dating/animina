defmodule Animina.FeatureFlags.FlagSetting do
  @moduledoc """
  Schema for extended feature flag settings.

  Stores additional configuration for flags beyond the simple enable/disable
  provided by FunWithFlags, including:
  - auto_approve: whether to use a default value when the flag is disabled
  - auto_approve_value: the value to return when auto-approving
  - delay_ms: artificial delay for UX testing
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "feature_flag_settings" do
    field :flag_name, :string
    field :description, :string
    field :settings, :map, default: %{}

    timestamps()
  end

  @doc """
  Changeset for creating a new flag setting.
  """
  def create_changeset(flag_setting, attrs) do
    flag_setting
    |> cast(attrs, [:flag_name, :description, :settings])
    |> validate_required([:flag_name])
    |> unique_constraint(:flag_name)
  end

  @doc """
  Changeset for updating an existing flag setting.
  """
  def update_changeset(flag_setting, attrs) do
    flag_setting
    |> cast(attrs, [:description, :settings])
  end
end
