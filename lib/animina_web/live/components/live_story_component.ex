defmodule AniminaWeb.LiveStoryComponent do
  @moduledoc """
  A LiveComponent for displaying moodboard stories.

  This component renders Markdown content with Earmark.

  ## Usage

      <.live_component
        module={AniminaWeb.LiveStoryComponent}
        id={"story-\#{@story.id}"}
        story={@story}
        variant={:quote}
      />

  ## Variants

  - `:quote` - Large quote card style (default)
  - `:caption` - Smaller caption style for combined cards

  ## Real-Time Updates

  To receive real-time updates, the parent LiveView must:
  1. Subscribe to the moodboard PubSub topic in mount
  2. Handle {:story_updated, story} messages
  3. Update the story assign which will re-render this component
  """

  use AniminaWeb, :live_component

  import Phoenix.HTML, only: [raw: 1]

  alias AniminaWeb.MoodboardComponents

  @impl true
  def update(assigns, socket) do
    story = assigns.story
    variant = Map.get(assigns, :variant, :quote)

    socket =
      socket
      |> assign(:story, story)
      |> assign(:variant, variant)
      |> assign(:rendered_content, MoodboardComponents.render_markdown(story.content))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= case @variant do %>
        <% :quote -> %>
          <.quote_card content={@rendered_content} />
        <% :caption -> %>
          <.caption_content content={@rendered_content} />
      <% end %>
    </div>
    """
  end

  defp quote_card(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-base-100 to-base-200/50 rounded-2xl p-6 sm:p-8 shadow-[0_6px_16px_-4px_rgba(0,0,0,0.1)] hover:shadow-[0_10px_24px_-4px_rgba(0,0,0,0.15)] transition-shadow duration-300">
      <div class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-headings:text-base-content">
        {raw(@content)}
      </div>
    </div>
    """
  end

  defp caption_content(assigns) do
    ~H"""
    <div class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-p:my-0">
      {raw(@content)}
    </div>
    """
  end
end
