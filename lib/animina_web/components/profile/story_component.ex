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
      if(assigns.photo, do: PubSub.subscribe(Animina.PubSub, "photo:updated:#{assigns.photo.id}"))
    end

    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.story_with_flags
        story={@story}
        current_user={@current_user}
        flags={@flags}
        user={@user}
        current_user_green_flags={@current_user_green_flags}
        current_user_red_flags={@current_user_red_flags}
        delete_story_modal_text={gettext("Are you sure?")}
      />
    </div>
    """
  end
end
