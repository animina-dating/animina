defmodule Animina.Wingman.PreheatedWingmanHint do
  @moduledoc """
  Schema for pre-computed wingman conversation hints.

  Hints are generated nightly for today's spotlight profiles so users
  see instant suggestions instead of waiting for on-demand AI generation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Animina.Accounts.User
  alias Animina.AI.Job

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "preheated_wingman_hints" do
    belongs_to :user, User
    belongs_to :other_user, User
    belongs_to :ai_job, Job

    field :shown_on, :date
    field :suggestions, {:array, :map}
    field :context_hash, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(hint, attrs) do
    hint
    |> cast(attrs, [
      :user_id,
      :other_user_id,
      :shown_on,
      :suggestions,
      :context_hash,
      :ai_job_id
    ])
    |> validate_required([:user_id, :other_user_id, :shown_on])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:other_user_id)
    |> foreign_key_constraint(:ai_job_id)
    |> unique_constraint([:user_id, :other_user_id, :shown_on])
  end
end
