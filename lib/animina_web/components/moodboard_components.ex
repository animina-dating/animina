defmodule AniminaWeb.MoodboardComponents do
  @moduledoc """
  Components for the moodboard feature including moodboard cards.
  """

  use Phoenix.Component
  use Gettext, backend: AniminaWeb.Gettext

  import Phoenix.HTML, only: [raw: 1]

  alias Animina.Photos
  alias AniminaWeb.ColumnToggle
  alias AniminaWeb.Helpers.ColumnPreferences

  # Default intro prompts for the "About Me" pinned item
  @default_intro_prompts [
    "Tell us about yourself...",
    "Erzähl uns etwas über dich..."
  ]

  @doc """
  Renders a moodboard card with photo, story, or combined content.

  ## Examples

      <.moodboard_card item={@item} current_user_id={@current_scope.user.id} owner?={true} />
  """
  attr :item, :map, required: true, doc: "Moodboard item with preloaded associations"
  attr :current_user_id, :string, default: nil
  attr :owner?, :boolean, default: false, doc: "Whether the current user owns this item"

  def moodboard_card(assigns) do
    ~H"""
    <div class={[
      "card bg-base-100 shadow-xl overflow-hidden",
      @item.state == "hidden" && "opacity-60 border-2 border-warning"
    ]}>
      <!-- Hidden indicator for owner -->
      <div
        :if={@item.state == "hidden" && @owner?}
        class="bg-warning text-warning-content px-3 py-1 text-sm"
      >
        <span class="font-medium">{gettext("Hidden")}</span>
        <span :if={@item.hidden_reason}>- {@item.hidden_reason}</span>
      </div>
      
    <!-- Photo content -->
      <figure :if={@item.item_type in ["photo", "combined"] && @item.moodboard_photo}>
        <.moodboard_photo photo={@item.moodboard_photo.photo} />
      </figure>
      
    <!-- Only show card-body if there's story content -->
      <div
        :if={@item.item_type in ["story", "combined"]}
        class="card-body"
      >
        <!-- Story content (Markdown) -->
        <div
          :if={@item.item_type in ["story", "combined"] && @item.moodboard_story}
          class="prose prose-sm max-w-none"
        >
          {raw(render_markdown(@item.moodboard_story.content))}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a moodboard photo with signed URL.

  Shows a loading placeholder for photos that are still being processed.
  Shows an "Analyzing" overlay for photos undergoing AI analysis.
  """
  attr :photo, :map, required: true
  attr :variant, :atom, default: :main, values: [:main, :thumbnail]
  attr :class, :string, default: "w-full h-auto"

  def moodboard_photo(assigns) do
    servable? = assigns.photo.state in Photos.servable_states()
    analyzing? = assigns.photo.state in Photos.analyzing_states()
    url = if servable?, do: Photos.signed_url(assigns.photo, assigns.variant), else: nil
    assigns = assign(assigns, url: url, servable?: servable?, analyzing?: analyzing?)

    ~H"""
    <div :if={@servable?} class="relative">
      <img src={@url} alt="" class={@class} loading="lazy" />
      <div
        :if={@analyzing?}
        class="absolute inset-0 bg-black/40 flex items-center justify-center rounded-lg"
      >
        <div class="flex flex-col items-center gap-2 text-white">
          <span class="loading loading-spinner loading-md"></span>
          <span class="text-sm font-medium">{gettext("Analyzing...")}</span>
        </div>
      </div>
    </div>
    <div
      :if={!@servable?}
      class={[
        @class,
        "relative bg-base-300 flex items-center justify-center min-h-20 rounded-lg"
      ]}
      title={gettext("AI review in progress")}
    >
      <span class="loading loading-spinner loading-md text-info"></span>
    </div>
    """
  end

  @doc """
  Renders an editorial-style masonry moodboard.
  Pinterest-like mixed heights with premium magazine feel.

  Supports 1, 2, or 3 columns on all screen sizes.
  """
  attr :items, :list, required: true
  attr :current_user_id, :string, default: nil
  attr :owner?, :boolean, default: false
  attr :columns, :integer, default: 2, doc: "Number of columns (1, 2, or 3)"
  attr :on_column_change, :string, default: nil, doc: "Event for column change"

  def editorial_moodboard(assigns) do
    ~H"""
    <div>
      <ColumnToggle.column_toggle columns={@columns} />
      
    <!-- Moodboard grid using Flexbox columns for consistent alignment -->
      <div class={[
        "flex gap-4 md:gap-5 lg:gap-6 pt-6",
        if(@columns == 1, do: "flex-col", else: "flex-row")
      ]}>
        <%= for {column_items, col_idx} <- distribute_to_columns(@items, @columns) do %>
          <div class="flex-1 flex flex-col gap-4 md:gap-5 lg:gap-6">
            <%= for item <- column_items do %>
              <div>
                <.editorial_card
                  item={item}
                  current_user_id={@current_user_id}
                  owner?={@owner?}
                />
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders an editorial-style card for the masonry moodboard.
  Supports photo cards, quote cards, and combined cards.
  """
  attr :item, :map, required: true
  attr :current_user_id, :string, default: nil
  attr :owner?, :boolean, default: false

  def editorial_card(assigns) do
    has_photo =
      assigns.item.item_type in ["photo", "combined"] && assigns.item.moodboard_photo != nil

    has_story =
      assigns.item.item_type in ["story", "combined"] && assigns.item.moodboard_story != nil

    has_custom_story =
      has_story && has_custom_content?(assigns.item.moodboard_story.content)

    assigns =
      assigns
      |> assign(:has_photo, has_photo)
      |> assign(:has_story, has_story)
      |> assign(:has_custom_story, has_custom_story)

    ~H"""
    <div class={[
      "group relative",
      @item.state == "hidden" && "opacity-60"
    ]}>
      <!-- Hidden badge for owner -->
      <div
        :if={@item.state == "hidden" && @owner?}
        class="absolute -top-2 -right-2 z-20 bg-warning text-warning-content px-2.5 py-1 text-xs font-medium rounded-full shadow-md"
      >
        {gettext("Hidden")}
      </div>
      
    <!-- Photo card -->
      <div :if={@has_photo && !@has_story} class="editorial-photo-card">
        <div class="rounded-2xl overflow-hidden shadow-[0_4px_20px_-4px_rgba(0,0,0,0.15)] hover:shadow-[0_8px_30px_-4px_rgba(0,0,0,0.2)] transition-shadow duration-300">
          <.moodboard_photo photo={@item.moodboard_photo.photo} class="w-full h-auto block" />
        </div>
      </div>
      
    <!-- Quote card (story only) -->
      <div :if={!@has_photo && @has_custom_story} class="editorial-quote-card">
        <div class="bg-gradient-to-br from-base-100 to-base-200/50 rounded-2xl p-6 sm:p-8 shadow-[0_6px_16px_-4px_rgba(0,0,0,0.1)] hover:shadow-[0_10px_24px_-4px_rgba(0,0,0,0.15)] transition-shadow duration-300">
          <div class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-headings:text-base-content">
            {raw(render_markdown(@item.moodboard_story.content))}
          </div>
        </div>
      </div>
      
    <!-- Combined card (photo + caption) -->
      <div :if={@has_photo && @has_story} class="editorial-combined-card">
        <div class="rounded-2xl overflow-hidden shadow-[0_4px_20px_-4px_rgba(0,0,0,0.15)] hover:shadow-[0_8px_30px_-4px_rgba(0,0,0,0.2)] transition-shadow duration-300 bg-base-100">
          <.moodboard_photo photo={@item.moodboard_photo.photo} class="w-full h-auto block" />
          
    <!-- Caption below photo (only if user wrote custom content) -->
          <div :if={@has_custom_story} class="p-5 sm:p-6">
            <div class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-p:my-0">
              {raw(render_markdown(@item.moodboard_story.content))}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an editorial-style card for the moodboard editor with drag handle and action buttons.
  A variant of `editorial_card` with editor overlays.
  """
  attr :item, :map, required: true
  attr :editing_item_id, :string, default: nil
  attr :edit_content, :string, default: ""

  def editorial_card_editor(assigns) do
    has_photo =
      assigns.item.item_type in ["photo", "combined"] && assigns.item.moodboard_photo != nil

    has_story =
      assigns.item.item_type in ["story", "combined"] && assigns.item.moodboard_story != nil

    is_pinned = Map.get(assigns.item, :pinned, false)

    is_editing = assigns.editing_item_id == assigns.item.id

    # Show inline edit hint for the pinned "About Me" item when it has default/empty content
    show_edit_hint =
      is_pinned && has_story &&
        (String.trim(assigns.item.moodboard_story.content || "") == "" ||
           assigns.item.moodboard_story.content in @default_intro_prompts)

    assigns =
      assigns
      |> assign(:has_photo, has_photo)
      |> assign(:has_story, has_story)
      |> assign(:is_pinned, is_pinned)
      |> assign(:is_editing, is_editing)
      |> assign(:show_edit_hint, show_edit_hint)

    ~H"""
    <div
      id={"item-#{@item.id}"}
      data-id={@item.id}
      data-pinned={to_string(@is_pinned)}
      class={[
        "group relative",
        @item.state == "hidden" && "opacity-60"
      ]}
    >
      <!-- Editor toolbar overlay -->
      <div class="absolute -top-3 left-0 right-0 z-20 flex items-center justify-between px-2">
        <!-- Drag handle (left) - hidden for pinned items -->
        <div
          :if={!@is_pinned}
          class="drag-handle cursor-grab active:cursor-grabbing bg-base-100/90 backdrop-blur-sm rounded-full p-2 shadow-md hover:shadow-lg transition-shadow"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5 text-base-content/60"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16" />
          </svg>
        </div>
        
    <!-- About Me badge for pinned items -->
        <div
          :if={@is_pinned}
          class="bg-primary text-primary-content px-3 py-1.5 text-xs font-medium rounded-full shadow-md"
        >
          {gettext("About Me")}
        </div>
        
    <!-- Action buttons (right) -->
        <div class="flex items-center gap-1">
          <!-- Edit button (for story/combined items) -->
          <button
            :if={@item.item_type in ["story", "combined"]}
            type="button"
            class="bg-base-100/90 backdrop-blur-sm rounded-full p-2 shadow-md hover:shadow-lg hover:bg-primary hover:text-primary-content transition-all"
            phx-click="edit-story"
            phx-value-id={@item.id}
            title={gettext("Edit text")}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
              />
            </svg>
          </button>
          
    <!-- Delete button - hidden for pinned items -->
          <button
            :if={!@is_pinned}
            type="button"
            class="bg-base-100/90 backdrop-blur-sm rounded-full p-2 shadow-md hover:shadow-lg hover:bg-error hover:text-error-content transition-all"
            phx-click="delete-item"
            phx-value-id={@item.id}
            title={gettext("Delete item")}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
              />
            </svg>
          </button>
        </div>
      </div>
      
    <!-- Hidden badge -->
      <div
        :if={@item.state == "hidden"}
        class="absolute top-4 right-4 z-10 bg-warning text-warning-content px-2.5 py-1 text-xs font-medium rounded-full shadow-md"
      >
        {gettext("Hidden")}
      </div>
      
    <!-- Photo card -->
      <div :if={@has_photo && !@has_story} class="editorial-photo-card pt-4">
        <div class="rounded-2xl overflow-hidden shadow-[0_4px_20px_-4px_rgba(0,0,0,0.15)] hover:shadow-[0_8px_30px_-4px_rgba(0,0,0,0.2)] transition-shadow duration-300">
          <.moodboard_photo photo={@item.moodboard_photo.photo} class="w-full h-auto block" />
        </div>
      </div>
      
    <!-- Quote card (story only, non-pinned) -->
      <div :if={!@has_photo && @has_story && !@is_pinned} class="editorial-quote-card pt-4">
        <div class="bg-gradient-to-br from-base-100 to-base-200/50 rounded-2xl p-6 sm:p-8 shadow-[0_6px_16px_-4px_rgba(0,0,0,0.1)] hover:shadow-[0_10px_24px_-4px_rgba(0,0,0,0.15)] transition-shadow duration-300">
          <div
            class="group/edit flex items-start gap-2 cursor-pointer hover:opacity-80 transition-opacity"
            phx-click="edit-story"
            phx-value-id={@item.id}
            title={gettext("Edit text")}
          >
            <div class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-headings:text-base-content flex-1">
              {raw(render_markdown(@item.moodboard_story.content))}
            </div>
          </div>
        </div>
      </div>
      
    <!-- Pinned item without photo (avatar not yet uploaded) -->
      <div :if={!@has_photo && @has_story && @is_pinned} class="editorial-pinned-placeholder pt-4">
        <div class="rounded-2xl overflow-hidden shadow-[0_4px_20px_-4px_rgba(0,0,0,0.15)] hover:shadow-[0_8px_30px_-4px_rgba(0,0,0,0.2)] transition-shadow duration-300 bg-base-100">
          <!-- Placeholder for avatar -->
          <div class="aspect-square bg-gradient-to-br from-base-200 to-base-300 flex flex-col items-center justify-center p-8">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-16 w-16 text-base-content/30 mb-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1.5"
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
            <p class="text-base-content/50 text-center text-sm">
              {gettext("Upload a profile photo to complete your About Me")}
            </p>
            <a href="/users/settings/avatar" class="btn btn-primary btn-sm mt-4">
              {gettext("Add Photo")}
            </a>
          </div>
          
    <!-- Story content -->
          <div class="p-5 sm:p-6">
            <div
              class="group/edit flex items-start gap-2 cursor-pointer hover:opacity-80 transition-opacity"
              phx-click="edit-story"
              phx-value-id={@item.id}
              title={gettext("Edit text")}
            >
              <div :if={@show_edit_hint} class="flex-1 text-base-content/40 italic">
                {gettext("Tell us about yourself...")}
              </div>
              <div
                :if={!@show_edit_hint}
                class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-p:my-0 flex-1"
              >
                {raw(render_markdown(@item.moodboard_story.content))}
              </div>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 flex-shrink-0 mt-1 text-base-content/40 group-hover/edit:text-primary transition-colors"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                />
              </svg>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Combined card (photo + caption) -->
      <div :if={@has_photo && @has_story} class="editorial-combined-card pt-4">
        <div class="rounded-2xl overflow-hidden shadow-[0_4px_20px_-4px_rgba(0,0,0,0.15)] hover:shadow-[0_8px_30px_-4px_rgba(0,0,0,0.2)] transition-shadow duration-300 bg-base-100">
          <.moodboard_photo photo={@item.moodboard_photo.photo} class="w-full h-auto block" />
          
    <!-- Caption below photo -->
          <div class="p-5 sm:p-6">
            <div
              class="group/edit flex items-start gap-2 cursor-pointer hover:opacity-80 transition-opacity"
              phx-click="edit-story"
              phx-value-id={@item.id}
              title={gettext("Edit text")}
            >
              <div :if={@show_edit_hint} class="flex-1 text-base-content/40 italic">
                {gettext("Tell us about yourself...")}
              </div>
              <div
                :if={!@show_edit_hint}
                class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-p:my-0 flex-1"
              >
                {raw(render_markdown(@item.moodboard_story.content))}
              </div>
              <svg
                :if={@show_edit_hint}
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 flex-shrink-0 mt-1 text-base-content/40 group-hover/edit:text-primary transition-colors"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                />
              </svg>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a placeholder card for empty moodboard columns.
  Shows grayed-out, blurred content to demonstrate what the moodboard could look like.
  """
  attr :variant, :atom, default: :photo, values: [:photo, :text]

  def placeholder_card(assigns) do
    ~H"""
    <div class="group relative opacity-60 select-none pointer-events-none">
      <!-- Photo-like placeholder -->
      <div :if={@variant == :photo} class="editorial-photo-card pt-4">
        <div class="rounded-2xl overflow-hidden shadow-[0_4px_20px_-4px_rgba(0,0,0,0.1)] bg-base-300">
          <div class="aspect-[4/5] bg-gradient-to-br from-base-300 via-base-200 to-base-300 flex items-center justify-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-16 w-16 text-base-content/40"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1.5"
                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
          </div>
        </div>
      </div>
      
    <!-- Text-like placeholder -->
      <div :if={@variant == :text} class="editorial-quote-card pt-4">
        <div class="bg-gradient-to-br from-base-200 to-base-300/50 rounded-2xl p-6 sm:p-8 shadow-[0_4px_12px_-4px_rgba(0,0,0,0.08)]">
          <div class="space-y-3" style="filter: blur(3px);">
            <div class="h-4 bg-base-content/50 rounded w-full"></div>
            <div class="h-4 bg-base-content/50 rounded w-5/6"></div>
            <div class="h-4 bg-base-content/50 rounded w-4/6"></div>
            <div class="h-4 bg-base-content/50 rounded w-full mt-4"></div>
            <div class="h-4 bg-base-content/50 rounded w-3/4"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Inline story editor component with markdown editor and save/cancel buttons.
  """
  attr :item, :map, required: true
  attr :edit_content, :string, default: ""

  def inline_story_editor(assigns) do
    ~H"""
    <form phx-submit="update-story-inline" phx-value-id={@item.id} class="space-y-3">
      <div
        id={"inline-story-editor-#{@item.id}"}
        phx-hook="MarkdownEditor"
        phx-update="ignore"
        data-initial-value={@edit_content}
        data-max-length="2000"
        data-input-name="content"
        data-placeholder={gettext("Write your text here...")}
      >
        <input type="hidden" name="content" value={@edit_content} />
        <p class="text-xs text-base-content/50 mt-2">
          <span data-char-counter>{String.length(@edit_content || "")}/2000</span>
        </p>
      </div>

      <div class="flex justify-end gap-2 pt-2">
        <button type="button" class="btn btn-ghost btn-sm" phx-click="cancel-inline-edit">
          {gettext("Cancel")}
        </button>
        <button type="submit" class="btn btn-primary btn-sm">
          {gettext("Save")}
        </button>
      </div>
    </form>
    """
  end

  @doc """
  Distributes items to columns in round-robin fashion.
  Returns a list of `{column_items, col_idx}` tuples.
  """
  def distribute_to_columns(items, num_columns) do
    num_columns = ColumnPreferences.validate_columns(num_columns)

    grouped =
      items
      |> Enum.with_index()
      |> Enum.group_by(fn {_item, idx} -> rem(idx, num_columns) end)

    Enum.map(0..(num_columns - 1), fn col_idx ->
      col_items = extract_column_items(grouped, col_idx)
      {col_items, col_idx}
    end)
  end

  defp extract_column_items(grouped, col_idx) do
    case Map.get(grouped, col_idx) do
      nil -> []
      indexed_items -> Enum.map(indexed_items, fn {item, _} -> item end)
    end
  end

  defdelegate render_markdown(content),
    to: AniminaWeb.Helpers.MarkdownHelpers,
    as: :render_story_markdown

  # Check if story content is custom (not empty or a default prompt)
  defp has_custom_content?(nil), do: false
  defp has_custom_content?(content) when content in @default_intro_prompts, do: false
  defp has_custom_content?(content), do: String.trim(content) != ""
end
