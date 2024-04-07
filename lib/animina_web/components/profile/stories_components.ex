defmodule AniminaWeb.StoriesComponents do
  @moduledoc """
  Provides Story UI components.
  """
  use Phoenix.Component

  attr :stories, :list, required: true
  attr :current_user, :any, required: true

  def stories_display(assigns) do
    ~H"""
    <div class="gap-8 columns-1 md:columns-2 lg:columns-3">
      <%= for story <- @stories do %>
        <.story story={story} current_user={@current_user} />
      <% end %>
    </div>
    """
  end

  attr :story, :any, required: true
  attr :current_user, :any, required: true

  def story(assigns) do
    ~H"""
    <div class="pb-4">
      <div :if={@story.photo} class="pb-4">
        <img
          class="object-cover rounded-lg"
          src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @story.photo.filename}
        />
      </div>
      <div :if={@story.headline} class="pb-4">
        <h3 class="text-lg font-semibold dark:text-white"><%= @story.headline.subject %></h3>
      </div>
      <div :if={@story.content} class="pb-4">
        <p class="text-justify text-gray-600 dark:text-gray-100"><%= @story.content %></p>
      </div>
      <hr />
    </div>
    """
  end
end
