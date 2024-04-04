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
    <div class="rounded-lg   w-[100%]   pb-4">
      <div class="h-[250px]">
        <img
          :if={@story.photo != nil}
          class="object-cover h-[100%] w-[100%] rounded-lg"
          src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @story.photo.filename}
        />
      </div>
      <div>
        <div :if={@story.headline != nil} class="pt-4 px-4">
          <h3 class="text-lg dark:text-white font-semibold"><%= @story.headline.subject %></h3>
        </div>

        <div :if={@story.content != nil} class="pt-1 px-4">
          <p class="text-gray-600 dark:text-gray-100"><%= @story.content %></p>
        </div>
      </div>
    </div>
    """
  end
end
