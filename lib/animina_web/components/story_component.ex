defmodule AniminaWeb.StoryComponent do
  @moduledoc """
  This component renders the story card.
  """
  use AniminaWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rounded-lg border border-gray-100 shadow-sm pb-4">
      <div class="h-200">
        <img
          :if={@story.photo != nil}
          class="object-cover rounded-t-lg"
          src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @story.photo.filename}
        />
      </div>

      <div :if={@story.headline != nil} class="pt-4 px-4">
        <h3 class="text-lg font-semibold"><%= @story.headline.subject %></h3>
      </div>

      <%!-- <p class="truncate text-sm text-gray-300">
        <time phx-hook="LocalTime" id={"#{@story.id}-story-time"} class="invisible">
          <%= DateTime.to_string(@story.created_at) %>
        </time>
      </p> --%>

      <div :if={@story.content != nil} class="pt-1 px-4">
        <p class="text-gray-600"><%= @story.content %></p>
      </div>
    </div>
    """
  end
end
