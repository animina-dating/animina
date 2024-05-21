defmodule AniminaWeb.BookmarkComponent do
  @moduledoc """
  This component renders the bookmark card.
  """
  use AniminaWeb, :live_component
  alias Phoenix.PubSub
  alias Animina.Traits.UserFlags

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "bookmark:updated:#{assigns.bookmark.id}")
      PubSub.subscribe(Animina.PubSub, "bookmark:deleted:#{assigns.bookmark.id}")
    end

    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

  defp get_intersecting_flags_count(first_flag_array, second_flag_array) do
    first_flag_array = Enum.map(first_flag_array, fn x -> x.id end)
    second_flag_array = Enum.map(second_flag_array, fn x -> x.id end)

    IO.inspect(first_flag_array, label: "first_flag_array")
    IO.inspect(second_flag_array, label: "second_flag_array")

    Enum.count(first_flag_array, &(&1 in second_flag_array))
    
  end

  defp filter_flags(nil, _color, _language) do
    []
  end

  defp filter_flags(user_id, color, language) do
    case UserFlags.by_user_id(user_id) do
      {:ok, traits} ->
        traits
        |> Enum.filter(fn trait ->
          trait.color == color
        end)
        |> Enum.map(fn trait ->
          %{
            id: trait.flag.id
          }
        end)


      _ ->
        []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
    <%= inspect get_intersecting_flags_count(
      filter_flags(@current_user.id, :red, @language),
      filter_flags(@bookmark.user.id, :red, @language)
    ) %>
    <%= @bookmark.user.id %>
      <.bookmark
        bookmark={@bookmark}
        dom_id={@dom_id}
        reason={@reason}
        current_user={@current_user}
        delete_bookmark_modal_text={gettext("Are you sure?")}
        intersecting_green_flags_count={get_intersecting_flags_count(
          filter_flags(@current_user.id, :green, @language),
          filter_flags(@bookmark.user.id, :green, @language)
        )}
        intersecting_red_flags_count={get_intersecting_flags_count(
          filter_flags(@current_user.id, :red, @language),
          filter_flags(@bookmark.user.id, :red, @language)
        )}
      />
    </div>
    """
  end
end
