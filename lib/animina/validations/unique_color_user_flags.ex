defmodule Animina.Validations.UniqueColorUserFlags do
  use Ash.Resource.Validation
  alias Animina.Traits

  @moduledoc """
  This is a module for validating that a user can only have one flag of the opposite color.
  """

  @impl true
  def init(opts) do
    case is_atom(opts[:attribute]) do
      true -> {:ok, opts}
      _ -> {:error, "attribute must be an atom!"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    user_id = Ash.Changeset.get_attribute(changeset, opts[:user_id])
    color = Ash.Changeset.get_attribute(changeset, opts[:color])
    flag_id = Ash.Changeset.get_attribute(changeset, opts[:flag_id])

    case get_selected_opposite_color_flags_for_user(user_id, color, flag_id) do
      [] -> :ok
      _ -> {:error, "You can only have one flag of the opposite color!"}
    end
  end

  defp get_selected_opposite_color_flags_for_user(user_id, color, flag_id) do
    Traits.UserFlags
    |> Ash.Query.for_read(:by_user_id, %{id: user_id, color: get_opposite_color(color)})
    |> Traits.read!()
    |> Enum.filter(fn user_flag -> user_flag.flag_id == flag_id end)
  end

  defp get_opposite_color(color) do
    case color do
      :white -> :white
      :green -> :red
      :red -> :green
    end
  end
end
