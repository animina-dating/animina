defmodule Animina.Accounts.Locations do
  @moduledoc """
  User location management functions.
  """

  import Ecto.Query

  alias Animina.Accounts.{User, UserLocation}
  alias Animina.Repo
  alias Animina.Utils.PaperTrail, as: PT

  @max_locations 4

  @doc """
  Returns the maximum number of locations a user can have.
  """
  def max_locations, do: @max_locations

  @doc """
  Lists all locations for a user, ordered by position.
  """
  def list_user_locations(%User{id: user_id}) do
    from(l in UserLocation,
      where: l.user_id == ^user_id,
      order_by: [asc: l.position]
    )
    |> Repo.all()
  end

  @doc """
  Adds a new location for a user.
  Automatically assigns the next available position (max #{@max_locations}).
  """
  def add_user_location(%User{id: user_id}, attrs, opts \\ []) do
    current_count = count_user_locations(user_id)

    if current_count >= @max_locations do
      {:error, :max_locations_reached}
    else
      next_position =
        (from(l in UserLocation,
           where: l.user_id == ^user_id,
           select: max(l.position)
         )
         |> Repo.one() || 0) + 1

      %UserLocation{}
      |> UserLocation.changeset(
        attrs
        |> Map.put(:user_id, user_id)
        |> Map.put(:position, next_position)
      )
      |> PaperTrail.insert(PT.opts(opts))
      |> PT.unwrap()
    end
  end

  @doc """
  Updates an existing location for a user (e.g. change zip code or country).
  """
  def update_user_location(%User{id: user_id}, location_id, attrs, opts \\ []) do
    case Repo.get_by(UserLocation, id: location_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      location ->
        location
        |> UserLocation.changeset(attrs)
        |> PaperTrail.update(PT.opts(opts))
        |> PT.unwrap()
    end
  end

  @doc """
  Removes a user location by its ID.
  """
  def remove_user_location(%User{id: user_id}, location_id, opts \\ []) do
    current_count = count_user_locations(user_id)

    if current_count <= 1 do
      {:error, :last_location}
    else
      case Repo.get_by(UserLocation, id: location_id, user_id: user_id) do
        nil -> {:error, :not_found}
        location -> PaperTrail.delete(location, PT.opts(opts)) |> PT.unwrap()
      end
    end
  end

  defp count_user_locations(user_id) do
    from(l in UserLocation, where: l.user_id == ^user_id, select: count())
    |> Repo.one()
  end
end
