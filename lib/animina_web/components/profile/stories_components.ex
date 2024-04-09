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
      <div class="pt-2 ">
        <%= for flag <- @flags do %>
          <span class="inline-flex  items-center px-2 py-1 text-base my-1 mx-1 font-medium text-blue-700 bg-blue-100 rounded-md">
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
    <%= if @story.headline.subject == "About me" do %>
      <div class="break-after-column" />
    <% end %>
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
    <%= if @story.headline.subject == "About me" do %>
      <div class="break-after-column" />
    <% end %>
    """
  end

  attr :story, :any, required: true

  def story_body(assigns) do
    ~H"""
    <%= if @story.headline.subject != "About me" do %>
      <div :if={@story.headline} class="pb-4">
        <h3 class="text-lg font-semibold dark:text-white"><%= @story.headline.subject %></h3>
      </div>
    <% end %>
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
      |> Phoenix.HTML.raw() %>
    </div>
    """
  end

  attr :flag, :any, required: true
  attr :current_user_green_flags, :list, required: true
  attr :current_user_red_flags, :list, required: true

  def get_styling_for_matching_flags(assigns) do
    ~H"""
    <div class="pl-2">
      <div :if={@flag.flag.name in @current_user_green_flags}>
        <p class="h-3 w-3 rounded-full bg-green-500" />
      </div>

      <div :if={@flag.flag.name in @current_user_red_flags}>
        <p class="h-3 w-3 rounded-full bg-red-500" />
      </div>
    </div>
    """
  end
end
