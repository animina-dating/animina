defmodule AniminaWeb.StoriesComponents do
  @moduledoc """
  Provides Story UI components.
  """
  use Phoenix.Component

  attr :stories_and_flags, :list, required: true
  attr :current_user, :any, required: true
  attr :current_user_green_flags, :list, required: true
  attr :current_user_red_flags, :list, required: true

  def stories_display(assigns) do
    ~H"""
    <div class="gap-8 columns-1 md:columns-2 lg:columns-3">
      <%= for {story, flags} <- @stories_and_flags do %>
        <.story_with_flags
          story={story}
          current_user={@current_user}
          flags={flags}
          current_user_green_flags={@current_user_green_flags}
          current_user_red_flags={@current_user_red_flags}
        />
      <% end %>
    </div>
    """
  end

  attr :story, :any, required: true
  attr :flags, :list, required: true
  attr :current_user, :any, required: true
  attr :current_user_green_flags, :list, required: true
  attr :current_user_red_flags, :list, required: true

  def story_with_flags(assigns) do
    ~H"""
    <div class="pb-2">
      <div :if={@story.photo} class="">
        <%= if @story.headline.subject == "About me" do %>
          <img
            class="object-cover rounded-lg aspect-square"
            src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @story.photo.filename}
          />
        <% else %>
          <img
            class="object-cover rounded-lg"
            src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @story.photo.filename}
          />
        <% end %>
      </div>
      <.story_body story={@story} />
      <div class="bg-green-100 rounded-md">
        <div class="flex flex-wrap justify-center p-2">
          <%= for flag <- @flags do %>
            <span class="inline-flex items-center px-2 py-1 mx-1 my-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-md">
              <%= flag.flag.emoji %> <%= flag.flag.name %>
              <.get_styling_for_matching_flags
                flag={flag}
                current_user_green_flags={@current_user_green_flags}
                current_user_red_flags={@current_user_red_flags}
              />
            </span>
          <% end %>
        </div>
      </div>
    </div>
    <div class="pb-4" />
    """
  end

  attr :story, :any, required: true
  attr :current_user, :any, required: true

  def story(assigns) do
    ~H"""
    <div class="pb-4">
      <div :if={@story.photo} class="pb-4">
        <%= if @story.headline.subject == "About me" do %>
          <img
            class="object-cover rounded-lg aspect-square"
            src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @story.photo.filename}
          />
        <% else %>
          <img
            class="object-cover rounded-lg"
            src={AniminaWeb.Endpoint.url() <> "/uploads/" <> @story.photo.filename}
          />
        <% end %>
      </div>
      <.story_body story={@story} />
      <hr />
    </div>
    """
  end

  attr :story, :any, required: true

  def story_body(assigns) do
    ~H"""
    <div :if={@story.headline} class="pb-4">
      <%= if @story.headline && @story.headline.subject != "About me" do %>
        <h3 class="text-lg font-semibold dark:text-white"><%= @story.headline.subject %></h3>
      <% end %>
    </div>
    <.story_content story={@story} />
    """
  end

  def story_content(assigns) do
    ~H"""
    <div :if={@story.content} class="pb-4 text-justify text-gray-600 dark:text-gray-100">
      <%= MDEx.to_html(@story.content,
        render: [unsafe_: true],
        features: [sanitize: true, syntax_highlight_theme: "github_light"]
      )
      |> String.replace(~r/\<a/, "<a class='text-blue-800 underline decoration-blue-800'")
      |> Phoenix.HTML.raw() %>
    </div>
    """
  end

  attr :flag, :any, required: true
  attr :current_user_green_flags, :list, required: true
  attr :current_user_red_flags, :list, required: true

  def get_styling_for_matching_flags(assigns) do
    ~H"""
    <div :if={@flag.flag.id in @current_user_green_flags} class="pl-2">
      <p class="w-3 h-3 bg-green-500 rounded-full" />
    </div>
    <div :if={@flag.flag.id in @current_user_red_flags} class="pl-2">
      <p class="w-3 h-3 bg-red-500 rounded-full" />
    </div>
    """
  end
end
