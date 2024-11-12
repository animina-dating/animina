defmodule AniminaWeb.StoryComponent do
  @moduledoc """
  This component renders the story card.
  """
  use AniminaWeb, :live_component
  alias Phoenix.PubSub

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "story:updated:#{assigns.story.id}")
      PubSub.subscribe(Animina.PubSub, "story:deleted:#{assigns.story.id}")
      if(assigns.photo, do: PubSub.subscribe(Animina.PubSub, "photo:updated:#{assigns.photo.id}"))
    end

    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

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
      <.story_card
        story={@story}
        current_user={@current_user}
        dom_id={@dom_id}
        state={
          if @story.photo && is_atom(@story.photo.state) do
            @story.photo.state
          else
            make_sure_photo_state_is_atom(@story.photo)
          end
        }
        user={@user}
        current_user_green_flags={@current_user_green_flags}
        language={@language}
        current_user_red_flags={@current_user_red_flags}
        delete_story_modal_text={
          with_locale(@language, fn -> gettext("Do you really want to delete this story?") end)
        }
      />
    </div>
    """
  end
end
