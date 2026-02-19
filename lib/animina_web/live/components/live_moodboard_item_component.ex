defmodule AniminaWeb.LiveMoodboardItemComponent do
  @moduledoc """
  A composite LiveComponent for displaying moodboard items.

  This component handles display of all three moodboard item types:

  - **photo** - Photo-only card
  - **story** - Text-only card
  - **combined** - Photo with caption card

  ## Usage

      <.live_component
        module={AniminaWeb.LiveMoodboardItemComponent}
        id={"moodboard-item-\#{@item.id}"}
        item={@item}
        owner?={@is_owner}
      />

  ## Real-Time Updates

  To receive real-time updates, the parent LiveView must:
  1. Subscribe to the `moodboard:<user_id>` topic in mount
  2. Subscribe to `photos:MoodboardItem:<item_id>` for each item with a photo
  3. Handle PubSub messages and re-fetch items
  4. The component will re-render when items change
  """

  use AniminaWeb, :live_component

  import Phoenix.HTML, only: [raw: 1]

  alias Animina.Photos
  alias AniminaWeb.MoodboardComponents
  alias AniminaWeb.PhotoStatus

  @impl true
  def update(assigns, socket) do
    item = assigns.item
    owner? = Map.get(assigns, :owner?, false)
    my_rating = Map.get(assigns, :my_rating, nil)
    rating_aggregates = Map.get(assigns, :rating_aggregates, %{})
    can_rate? = Map.get(assigns, :can_rate?, false)

    has_photo = item.item_type in ["photo", "combined"] && item.moodboard_photo != nil
    has_story = item.item_type in ["story", "combined"] && item.moodboard_story != nil

    socket =
      socket
      |> assign(:item, item)
      |> assign(:owner?, owner?)
      |> assign(:has_photo, has_photo)
      |> assign(:has_story, has_story)
      |> assign(:my_rating, my_rating)
      |> assign(:rating_aggregates, rating_aggregates)
      |> assign(:can_rate?, can_rate?)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={item_container_class(@item, @owner?)}>
      <!-- Hidden badge for owner -->
      <div
        :if={@item.state == "hidden" && @owner?}
        class="absolute -top-2 -right-2 z-20 bg-warning text-warning-content px-2.5 py-1 text-xs font-medium rounded-full shadow-md"
      >
        {gettext("Hidden")}
      </div>
      
    <!-- Photo-only card -->
      <.photo_card
        :if={@has_photo && !@has_story}
        item={@item}
        owner?={@owner?}
        can_rate?={@can_rate?}
        my_rating={@my_rating}
        rating_aggregates={@rating_aggregates}
      />
      
    <!-- Story-only card -->
      <.story_card
        :if={!@has_photo && @has_story}
        item={@item}
        owner?={@owner?}
        can_rate?={@can_rate?}
        my_rating={@my_rating}
        rating_aggregates={@rating_aggregates}
      />
      
    <!-- Combined card (photo + caption) -->
      <.combined_card
        :if={@has_photo && @has_story}
        item={@item}
        owner?={@owner?}
        can_rate?={@can_rate?}
        my_rating={@my_rating}
        rating_aggregates={@rating_aggregates}
      />
    </div>
    """
  end

  defp item_container_class(item, owner?) do
    base_classes = ["group relative"]

    if item.state == "hidden" && owner? do
      base_classes ++ ["opacity-60"]
    else
      base_classes
    end
  end

  defp photo_card(assigns) do
    photo = assigns.item.moodboard_photo.photo
    servable? = PhotoStatus.servable?(photo)
    analyzing? = PhotoStatus.analyzing?(photo)
    approved? = PhotoStatus.approved?(photo)
    url = if servable?, do: Photos.signed_url(photo, :main), else: nil

    assigns =
      assigns
      |> assign(:photo, photo)
      |> assign(:servable?, servable?)
      |> assign(:analyzing?, analyzing?)
      |> assign(:approved?, approved?)
      |> assign(:url, url)

    ~H"""
    <div class="editorial-photo-card">
      <div class="relative rounded-2xl overflow-hidden shadow-[0_4px_20px_-4px_rgba(0,0,0,0.15)] hover:shadow-[0_8px_30px_-4px_rgba(0,0,0,0.2)] transition-shadow duration-300">
        <%= if @owner? do %>
          <.owner_photo_view
            photo={@photo}
            url={@url}
            servable?={@servable?}
            analyzing?={@analyzing?}
          />
        <% else %>
          <.visitor_photo_view
            photo={@photo}
            url={@url}
            approved?={@approved?}
          />
        <% end %>
        <!-- Rating pill for visitors -->
        <div
          :if={@can_rate? && !@owner?}
          class="absolute bottom-3 left-0 right-0 z-10 flex justify-center"
        >
          <div class="flex items-center gap-1 rounded-full bg-black/60 backdrop-blur-sm px-2 py-1 shadow-lg">
            <.rating_buttons item={@item} my_rating={@my_rating} variant={:overlay} />
          </div>
        </div>
        <!-- Aggregate pill for owners -->
        <.overlay_aggregates :if={@owner?} rating_aggregates={@rating_aggregates} />
      </div>
    </div>
    """
  end

  defp story_card(assigns) do
    content = assigns.item.moodboard_story.content
    rendered = MoodboardComponents.render_markdown(content)
    assigns = assign(assigns, :rendered_content, rendered)

    ~H"""
    <div class="editorial-quote-card">
      <div class="bg-gradient-to-br from-base-100 to-base-200/50 rounded-2xl p-6 sm:p-8 shadow-[0_6px_16px_-4px_rgba(0,0,0,0.1)] hover:shadow-[0_10px_24px_-4px_rgba(0,0,0,0.15)] transition-shadow duration-300">
        <div class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-headings:text-base-content">
          {raw(@rendered_content)}
        </div>
        <!-- Rating for visitors -->
        <div
          :if={@can_rate? && !@owner?}
          class="flex items-center justify-center gap-3 pt-4 mt-4 border-t border-base-content/10"
        >
          <.rating_buttons item={@item} my_rating={@my_rating} variant={:inline} />
        </div>
        <!-- Aggregates for owners -->
        <.inline_aggregates rating_aggregates={@rating_aggregates} owner?={@owner?} />
      </div>
    </div>
    """
  end

  @default_intro_prompts [
    "Tell us about yourself...",
    "Erzähl uns etwas über dich..."
  ]

  defp combined_card(assigns) do
    photo = assigns.item.moodboard_photo.photo
    content = assigns.item.moodboard_story.content

    servable? = PhotoStatus.servable?(photo)
    analyzing? = PhotoStatus.analyzing?(photo)
    approved? = PhotoStatus.approved?(photo)
    url = if servable?, do: Photos.signed_url(photo, :main), else: nil

    has_custom_content =
      content != nil && String.trim(content) != "" && content not in @default_intro_prompts

    rendered = if has_custom_content, do: MoodboardComponents.render_markdown(content), else: ""

    assigns =
      assigns
      |> assign(:photo, photo)
      |> assign(:servable?, servable?)
      |> assign(:analyzing?, analyzing?)
      |> assign(:approved?, approved?)
      |> assign(:url, url)
      |> assign(:rendered_content, rendered)
      |> assign(:has_custom_content, has_custom_content)

    ~H"""
    <div class="editorial-combined-card">
      <div class="rounded-2xl overflow-hidden shadow-[0_4px_20px_-4px_rgba(0,0,0,0.15)] hover:shadow-[0_8px_30px_-4px_rgba(0,0,0,0.2)] transition-shadow duration-300 bg-base-100">
        <%= if @owner? do %>
          <.owner_photo_view
            photo={@photo}
            url={@url}
            servable?={@servable?}
            analyzing?={@analyzing?}
          />
        <% else %>
          <.visitor_photo_view
            photo={@photo}
            url={@url}
            approved?={@approved?}
          />
        <% end %>
        <!-- Caption below photo (only if user wrote custom content) -->
        <div :if={@has_custom_content} class="p-5 sm:p-6">
          <div class="prose prose-sm max-w-none prose-p:text-base-content/70 prose-p:leading-relaxed prose-p:my-0">
            {raw(@rendered_content)}
          </div>
        </div>
        <!-- Rating for visitors -->
        <div
          :if={@can_rate? && !@owner?}
          class="flex items-center justify-center gap-3 px-5 pb-4 pt-2 border-t border-base-content/10"
        >
          <.rating_buttons item={@item} my_rating={@my_rating} variant={:inline} />
        </div>
        <!-- Aggregates for owners -->
        <.inline_aggregates rating_aggregates={@rating_aggregates} owner?={@owner?} />
      </div>
    </div>
    """
  end

  defp owner_photo_view(assigns) do
    badge = PhotoStatus.badge_for_state(assigns.photo.state, assigns.photo.error_message)
    assigns = assign(assigns, :badge, badge)

    ~H"""
    <div>
      <%= if @servable? do %>
        <div class="relative">
          <img
            src={@url}
            alt=""
            class="w-full h-auto block cursor-pointer"
            loading="lazy"
            phx-click="enlarge_photo"
            phx-value-item-id={@photo.id}
          />
          <.status_overlay :if={@badge} badge={@badge} />
        </div>
      <% else %>
        <.processing_placeholder badge={@badge} />
      <% end %>
    </div>
    """
  end

  defp visitor_photo_view(assigns) do
    ~H"""
    <div>
      <%= if @approved? do %>
        <img
          src={@url}
          alt=""
          class="w-full h-auto block cursor-pointer"
          loading="lazy"
          phx-click="enlarge_photo"
          phx-value-item-id={@photo.id}
        />
      <% else %>
        <.review_placeholder />
      <% end %>
    </div>
    """
  end

  defp status_overlay(assigns) do
    ~H"""
    <div class={[
      "absolute inset-0 flex items-center justify-center",
      PhotoStatus.badge_overlay_class(@badge.type)
    ]}>
      <div class="flex flex-col items-center gap-2 text-white p-4 text-center">
        <span :if={@badge.spinner} class="loading loading-spinner loading-md"></span>
        <.icon :if={@badge.icon} name={@badge.icon} class="h-6 w-6" />
        <span class="text-sm font-medium">{@badge.text}</span>
      </div>
    </div>
    """
  end

  defp processing_placeholder(assigns) do
    ~H"""
    <div class="relative bg-base-300 flex items-center justify-center min-h-32 aspect-square">
      <div class="flex flex-col items-center gap-2 text-base-content/60">
        <span :if={@badge && @badge.spinner} class="loading loading-spinner loading-md"></span>
        <.icon :if={@badge && @badge.icon} name={@badge.icon} class="h-8 w-8" />
        <span class="text-sm font-medium">{@badge && @badge.text}</span>
      </div>
    </div>
    """
  end

  defp review_placeholder(assigns) do
    ~H"""
    <div class="relative bg-base-300 flex items-center justify-center min-h-32 aspect-square">
      <div class="flex flex-col items-center gap-2 text-base-content/60">
        <.icon name="hero-clock" class="h-8 w-8" />
        <span class="text-sm font-medium">{gettext("In review")}</span>
      </div>
    </div>
    """
  end

  # Reusable rating buttons — rendered inside each card's own container.
  # `variant` controls colors: `:overlay` for dark photo backgrounds, `:inline` for card backgrounds.
  defp rating_buttons(assigns) do
    overlay? = assigns.variant == :overlay
    assigns = assign(assigns, :overlay?, overlay?)

    ~H"""
    <button
      phx-click="rate_item"
      phx-value-item-id={@item.id}
      phx-value-rating="-1"
      class={[
        "btn btn-circle btn-sm btn-ghost",
        if(@my_rating == -1,
          do: "text-error bg-error/20",
          else:
            if(@overlay?,
              do: "text-white/70 hover:text-error hover:bg-error/20",
              else: "text-base-content/40 hover:text-error hover:bg-error/10"
            )
        )
      ]}
      title={gettext("Dislike")}
    >
      <.icon name="hero-hand-thumb-down-mini" class="h-4 w-4" />
    </button>

    <button
      phx-click="rate_item"
      phx-value-item-id={@item.id}
      phx-value-rating="1"
      class={[
        "btn btn-circle btn-sm btn-ghost",
        if(@my_rating == 1,
          do: "text-success bg-success/20",
          else:
            if(@overlay?,
              do: "text-white/70 hover:text-success hover:bg-success/20",
              else: "text-base-content/40 hover:text-success hover:bg-success/10"
            )
        )
      ]}
      title={gettext("Like")}
    >
      <.icon name="hero-hand-thumb-up-mini" class="h-4 w-4" />
    </button>

    <button
      phx-click="rate_item"
      phx-value-item-id={@item.id}
      phx-value-rating="2"
      class={[
        "btn btn-sm btn-ghost px-1",
        if(@my_rating == 2,
          do: "text-info bg-info/20",
          else:
            if(@overlay?,
              do: "text-white/70 hover:text-info hover:bg-info/20",
              else: "text-base-content/40 hover:text-info hover:bg-info/10"
            )
        )
      ]}
      title={gettext("Love")}
    >
      <span class="inline-flex items-center">
        <span class="overflow-hidden" style="width:10px">
          <.icon name="hero-hand-thumb-up-mini" class="h-4 w-4" />
        </span>
        <.icon name="hero-hand-thumb-up-mini" class="h-4 w-4" />
      </span>
    </button>
    """
  end

  # Overlay aggregates for photo cards (owner view)
  defp overlay_aggregates(assigns) do
    agg = assigns.rating_aggregates
    has_any = map_size(agg) > 0

    assigns =
      assigns
      |> assign(:has_any, has_any)
      |> assign(:dislike_count, Map.get(agg, -1, 0))
      |> assign(:like_count, Map.get(agg, 1, 0))
      |> assign(:love_count, Map.get(agg, 2, 0))

    ~H"""
    <div :if={@has_any} class="absolute bottom-3 left-0 right-0 z-10 flex justify-center">
      <div class="flex items-center gap-3 rounded-full bg-black/60 backdrop-blur-sm px-3 py-1.5 shadow-lg text-xs text-white/70">
        <span :if={@dislike_count > 0} class="flex items-center gap-1" title={gettext("Dislike")}>
          <.icon name="hero-hand-thumb-down-mini" class="h-3.5 w-3.5" />
          {@dislike_count}
        </span>
        <span :if={@like_count > 0} class="flex items-center gap-1" title={gettext("Like")}>
          <.icon name="hero-hand-thumb-up-mini" class="h-3.5 w-3.5" />
          {@like_count}
        </span>
        <span :if={@love_count > 0} class="flex items-center gap-1" title={gettext("Love")}>
          <span class="inline-flex items-center">
            <span class="overflow-hidden" style="width:8px">
              <.icon name="hero-hand-thumb-up-mini" class="h-3.5 w-3.5" />
            </span>
            <.icon name="hero-hand-thumb-up-mini" class="h-3.5 w-3.5" />
          </span>
          {@love_count}
        </span>
      </div>
    </div>
    """
  end

  # Inline aggregates for story/combined cards (owner view)
  defp inline_aggregates(assigns) do
    agg = assigns.rating_aggregates
    has_any = map_size(agg) > 0 && assigns.owner?

    assigns =
      assigns
      |> assign(:has_any, has_any)
      |> assign(:dislike_count, Map.get(agg, -1, 0))
      |> assign(:like_count, Map.get(agg, 1, 0))
      |> assign(:love_count, Map.get(agg, 2, 0))

    ~H"""
    <div
      :if={@has_any}
      class="flex items-center justify-center gap-3 px-5 pb-4 pt-2 border-t border-base-content/10 text-xs text-base-content/40"
    >
      <span :if={@dislike_count > 0} class="flex items-center gap-1" title={gettext("Dislike")}>
        <.icon name="hero-hand-thumb-down-mini" class="h-3.5 w-3.5" />
        {@dislike_count}
      </span>
      <span :if={@like_count > 0} class="flex items-center gap-1" title={gettext("Like")}>
        <.icon name="hero-hand-thumb-up-mini" class="h-3.5 w-3.5" />
        {@like_count}
      </span>
      <span :if={@love_count > 0} class="flex items-center gap-1" title={gettext("Love")}>
        <span class="inline-flex items-center">
          <span class="overflow-hidden" style="width:8px">
            <.icon name="hero-hand-thumb-up-mini" class="h-3.5 w-3.5" />
          </span>
          <.icon name="hero-hand-thumb-up-mini" class="h-3.5 w-3.5" />
        </span>
        {@love_count}
      </span>
    </div>
    """
  end
end
