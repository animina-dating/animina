defmodule Animina.Discovery.Schemas.Inquiry do
  @moduledoc """
  Schema for tracking first-contact inquiries between users.

  An inquiry is recorded when someone initiates contact with another user
  (e.g., sending their first message). This is used to:
  - Track daily inquiry counts for popular user protection
  - Compute rolling averages for popularity-based scoring adjustments
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Animina.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_inquiries" do
    belongs_to :sender, User
    belongs_to :receiver, User

    field :inquiry_date, :date

    timestamps(type: :utc_datetime)
  end

  def changeset(inquiry, attrs) do
    inquiry
    |> cast(attrs, [:sender_id, :receiver_id, :inquiry_date])
    |> validate_required([:sender_id, :receiver_id, :inquiry_date])
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:receiver_id)
    |> unique_constraint([:sender_id, :receiver_id])
  end
end
