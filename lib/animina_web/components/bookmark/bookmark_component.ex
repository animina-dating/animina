defmodule AniminaWeb.BookmarkComponent do
  @moduledoc """
  This component renders the bookmark card.
  """
  use AniminaWeb, :live_component
  alias Animina.Traits.UserFlags
  alias Phoenix.PubSub
  import Gettext, only: [with_locale: 2]

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

    Enum.count(first_flag_array, &(&1 in second_flag_array))
  end

  defp filter_flags(nil, _color, _language) do
    []
  end

  defp filter_flags(user_id, color, _language) do
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

  # we display the state as an atom in the photo struct, but we need to make sure it is an atom
  # as we are using it for pattern matching

  defp make_sure_photo_state_is_atom(nil) do
    ""
  end

  defp make_sure_photo_state_is_atom(photo) do
    String.to_atom(photo.state)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bookmark
        bookmark={@bookmark}
        dom_id={@dom_id}
        language={@language}
        reason={@reason}
        current_user={@current_user}
        state={
          if @current_user.profile_photo && is_atom(@current_user.profile_photo.state) do
            @current_user.profile_photo.state
          else
            make_sure_photo_state_is_atom(@current_user.profile_photo)
          end
        }
        delete_bookmark_modal_text={
          with_locale(@language, fn -> gettext("Do you really want to delete this bookmark?") end)
        }
        intersecting_green_flags_count={
          get_intersecting_flags_count(
            filter_flags(@current_user.id, :green, @language),
            filter_flags(@bookmark.user.id, :white, @language)
          )
        }
        intersecting_red_flags_count={
          get_intersecting_flags_count(
            filter_flags(@current_user.id, :red, @language),
            filter_flags(@bookmark.user.id, :white, @language)
          )
        }
      />
    </div>
    """
  end
end
