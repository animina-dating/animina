defmodule AniminaWeb.Helpers.ColumnPreferences do
  @moduledoc """
  Shared column preference logic for grid layouts (moodboard, discover, etc.).

  Provides functions for reading, persisting, and converting column preferences.
  Used by MoodboardEditor, ProfileMoodboard, and SpotlightLive.
  """

  alias Animina.Accounts

  @doc """
  Returns the user's saved column preference.
  """
  def get_columns_for_user(user) do
    user.grid_columns || 3
  end

  @doc """
  Returns default columns when no user preference is available.
  """
  def default_columns do
    3
  end

  @doc """
  Validates a column count, returning 1, 2, or 3 (defaults to 3).
  """
  def validate_columns(columns) when columns in [1, 2, 3], do: columns
  def validate_columns(_), do: 3

  @doc """
  Returns the CSS grid class for the given column count.
  """
  def grid_class(columns) do
    case columns do
      1 -> "grid-cols-1"
      2 -> "grid-cols-2"
      3 -> "grid-cols-3"
      _ -> "grid-cols-2"
    end
  end

  @doc """
  Returns a responsive CSS grid class that only applies at the `sm:` breakpoint.
  Caps at 2 columns for large phones (640px+).
  """
  def sm_grid_class(columns) do
    case min(columns, 2) do
      1 -> "sm:grid-cols-1"
      2 -> "sm:grid-cols-2"
    end
  end

  @doc """
  Returns a responsive CSS grid class that only applies at the `md:` breakpoint.
  Allows 3 columns for tablets/iPads (768px+).
  """
  def md_grid_class(columns) do
    case columns do
      1 -> "md:grid-cols-1"
      2 -> "md:grid-cols-2"
      3 -> "md:grid-cols-3"
      _ -> "md:grid-cols-3"
    end
  end

  @doc """
  Persists a column preference and returns `{columns, updated_user}`.

  The caller must update its user assign with the returned user so that
  subsequent reads (including after live navigation) see the new value.
  """
  def persist_columns(user, columns_str) do
    columns = String.to_integer(columns_str)

    updated_user =
      case Accounts.update_grid_columns(user, columns) do
        {:ok, user} -> user
        {:error, _} -> user
      end

    {columns, updated_user}
  end

  @doc """
  Updates the user inside `current_scope` assigns after a column change.
  Call this after `persist_columns` so that live navigation sees the new value.
  """
  def update_scope_user(socket, updated_user) do
    scope = socket.assigns.current_scope
    Phoenix.Component.assign(socket, :current_scope, %{scope | user: updated_user})
  end
end
