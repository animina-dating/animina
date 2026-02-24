defmodule AniminaWeb.LivePhotoComponent do
  @moduledoc """
  A LiveComponent for displaying photos with appropriate status badges.

  This component handles the display logic for photos in different states,
  showing different UI for owners vs non-owners.

  ## Usage

      <.live_component
        module={AniminaWeb.LivePhotoComponent}
        id={"photo-\#{@photo.id}"}
        photo={@photo}
        owner?={@is_owner}
        variant={:main}
        class="w-full h-auto"
      />

  ## Owner vs Non-Owner Views

  **For owners** (the user who uploaded the photo):
  - Shows detailed status badges: "Processing...", "Analyzing...", "Under review", error messages
  - Always displays the photo when available (even if not approved)

  **For non-owners** (visitors viewing someone else's profile):
  - Shows photo normally when approved
  - Shows generic "In review" placeholder for any non-approved state

  ## Real-Time Updates

  To receive real-time updates, the parent LiveView must:
  1. Subscribe to the photo's PubSub topic in mount
  2. Handle {:photo_state_changed, photo} messages
  3. Update the photo assign which will re-render this component
  """

  use AniminaWeb, :live_component

  alias Animina.Photos
  alias AniminaWeb.PhotoStatus

  @impl true
  def update(%{photo: photo} = assigns, socket) do
    owner? = Map.get(assigns, :owner?, false)
    variant = Map.get(assigns, :variant, :main)
    class = Map.get(assigns, :class, "w-full h-auto")

    servable? = PhotoStatus.servable?(photo)
    approved? = PhotoStatus.approved?(photo)
    url = if servable?, do: Photos.signed_url(photo, variant), else: nil

    # For non-owners: show pixelated preview when photo is servable but not approved
    review_pixel_url =
      if !owner? && servable? && !approved? do
        Photos.signed_url(photo, :review_pixel)
      end

    socket =
      socket
      |> assign(:photo, photo)
      |> assign(:owner?, owner?)
      |> assign(:variant, variant)
      |> assign(:class, class)
      |> assign(:servable?, servable?)
      |> assign(:analyzing?, PhotoStatus.analyzing?(photo))
      |> assign(:processing?, PhotoStatus.processing?(photo))
      |> assign(:url, url)
      |> assign(:review_pixel_url, review_pixel_url)
      |> assign(:status_badge, status_badge(photo, owner?))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <%= if @owner? do %>
        <.owner_view
          url={@url}
          class={@class}
          servable?={@servable?}
          processing?={@processing?}
          analyzing?={@analyzing?}
          status_badge={@status_badge}
        />
      <% else %>
        <.visitor_view
          photo={@photo}
          url={@url}
          class={@class}
          review_pixel_url={@review_pixel_url}
        />
      <% end %>
    </div>
    """
  end

  defp owner_view(assigns) do
    ~H"""
    <div>
      <%= if @servable? do %>
        <div class="relative">
          <img src={@url} alt="" class={@class} loading="lazy" />
          <.status_overlay :if={@status_badge} badge={@status_badge} />
        </div>
      <% else %>
        <.processing_placeholder class={@class} badge={@status_badge} />
      <% end %>
    </div>
    """
  end

  defp visitor_view(assigns) do
    approved? = PhotoStatus.approved?(assigns.photo)
    assigns = assign(assigns, approved?: approved?)

    ~H"""
    <div>
      <%= if @approved? do %>
        <img src={@url} alt="" class={@class} loading="lazy" />
      <% else %>
        <.review_placeholder class={@class} review_pixel_url={@review_pixel_url} />
      <% end %>
    </div>
    """
  end

  defp status_overlay(assigns) do
    ~H"""
    <div class={[
      "absolute inset-0 flex items-center justify-center rounded-lg",
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
    <div class={[
      @class,
      "relative bg-base-300 flex items-center justify-center min-h-32 rounded-lg"
    ]}>
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
    <%= if @review_pixel_url do %>
      <div class="relative rounded-lg overflow-hidden">
        <img src={@review_pixel_url} alt="" class={@class} loading="lazy" />
        <div class="absolute inset-0 bg-black/40 flex items-center justify-center">
          <div class="flex flex-col items-center gap-2 text-white">
            <.icon name="hero-clock" class="h-8 w-8" />
            <span class="text-sm font-medium">{gettext("In review")}</span>
          </div>
        </div>
      </div>
    <% else %>
      <div class={[
        @class,
        "relative bg-base-300 flex items-center justify-center min-h-32 rounded-lg"
      ]}>
        <div class="flex flex-col items-center gap-2 text-base-content/60">
          <.icon name="hero-clock" class="h-8 w-8" />
          <span class="text-sm font-medium">{gettext("In review")}</span>
        </div>
      </div>
    <% end %>
    """
  end

  # Non-owners don't see badges (handled by visitor_view)
  defp status_badge(_photo, false), do: nil

  defp status_badge(photo, true),
    do: PhotoStatus.badge_for_state(photo.state, photo.error_message)
end
