defmodule AniminaWeb.DiscoverLive do
  @moduledoc """
  LiveView for the partner discovery page.

  Displays curated partner suggestions ("Your Matches") based on combined
  scoring, plus a "Wildcards" section with randomly picked profiles from
  a relaxed search pool (no flag checking).

  Features:
  - "Not interested" button for permanent dismissal
  - Soft-red warning indicators on match cards
  - Match statistics (green count, shared traits)
  - Wildcard profiles with distinct visual treatment
  """

  use AniminaWeb, :live_view

  import AniminaWeb.Helpers.UserHelpers, only: [get_location_info: 2, gender_symbol: 1]
  import AniminaWeb.Helpers.MarkdownHelpers, only: [strip_markdown: 1]

  alias Animina.Accounts
  alias Animina.Discovery
  alias Animina.GeoData
  alias Animina.Messaging
  alias Animina.Moodboard
  alias Animina.Traits
  alias AniminaWeb.ColumnToggle
  alias AniminaWeb.Helpers.AvatarHelpers
  alias AniminaWeb.Helpers.ColumnPreferences

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="discover-container" phx-hook="DeviceType" class="max-w-4xl mx-auto">
        <h1 class="text-2xl font-bold mb-4">{gettext("Discover")}</h1>

        <%!-- Collapsible Info Panel --%>
        <details class="mb-6 group">
          <summary class="flex items-center gap-2 cursor-pointer select-none text-sm text-base-content/60 hover:text-base-content/80 transition-colors">
            <.icon name="hero-information-circle" class="h-4 w-4 text-info" />
            <span class="font-medium">{gettext("How Discovery Works")}</span>
            <.icon
              name="hero-chevron-down-mini"
              class="h-4 w-4 transition-transform group-open:rotate-180"
            />
          </summary>
          <div class="bg-base-200/50 rounded-lg p-4 mt-2 text-sm text-base-content/70">
            <ul class="space-y-1 text-xs">
              <li>
                {gettext(
                  "You can have up to %{max} active conversations. Each day, you can start up to %{daily} new ones.",
                  max: @slot_status.max,
                  daily: @slot_status.daily_max
                )}
              </li>
              <li>{gettext("Take your time — choose who you really want to talk to.")}</li>
              <li>
                {gettext("You can \"Let go\" of a conversation in your messages to free a slot.")}
              </li>
            </ul>
          </div>
        </details>

        <%!-- Loading Skeleton --%>
        <div :if={@loading}>
          <div class={["grid gap-4", ColumnPreferences.grid_class(@columns)]}>
            <.skeleton_card :for={_ <- 1..4} />
          </div>
        </div>

        <%!-- Limit Warnings --%>
        <%= if @slots_full do %>
          <div class="alert alert-warning mb-6">
            <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
            <div>
              <p class="font-medium">
                {gettext("All chat slots are full")}
              </p>
              <p class="text-sm mt-1">
                {gettext("\"Let go\" of a conversation in your messages to see new discoveries.")}
              </p>
              <.link navigate={~p"/messages"} class="btn btn-sm btn-ghost mt-2">
                {gettext("Go to Messages")}
              </.link>
            </div>
          </div>
        <% end %>

        <%= if @daily_limit_reached && !@slots_full do %>
          <div class="alert alert-info mb-6">
            <.icon name="hero-clock" class="h-5 w-5" />
            <div>
              <p class="font-medium">
                {gettext("You've reached today's limit")}
              </p>
              <p class="text-sm mt-1">
                {gettext("New discoveries will be available tomorrow.")}
              </p>
            </div>
          </div>
        <% end %>

        <%!-- Your Matches Section --%>
        <div :if={!@loading && !@slots_full && !@daily_limit_reached} class="mb-8">
          <div class="flex items-center gap-2 mb-2">
            <.icon name="hero-sparkles" class="h-5 w-5 text-primary" />
            <h2 class="text-lg font-semibold">{gettext("Your Matches")}</h2>
          </div>

          <%!-- Column Toggle --%>
          <ColumnToggle.column_toggle columns={@columns} />

          <%!-- Matches Grid --%>
          <div class={["grid gap-4", ColumnPreferences.grid_class(@columns)]}>
            <%= if Enum.empty?(@matches) do %>
              <div class="col-span-full text-center py-12 text-base-content/50">
                <div class="w-16 h-16 rounded-full bg-base-200 flex items-center justify-center mx-auto mb-4">
                  <.icon name="hero-magnifying-glass" class="h-8 w-8 opacity-50" />
                </div>
                <p class="text-lg">{gettext("No suggestions available")}</p>
                <p class="text-sm mt-2 text-base-content/40">
                  {gettext("Try adjusting your preferences to expand your search.")}
                </p>
                <.link
                  navigate={~p"/settings/preferences"}
                  class="btn btn-primary btn-sm mt-4"
                >
                  {gettext("Adjust Preferences")}
                </.link>
              </div>
            <% else %>
              <.profile_card
                :for={suggestion <- @matches}
                suggestion={suggestion}
                variant={:match}
                city_names={@city_names}
                avatar_photos={@avatar_photos}
                story_previews={@story_previews}
                visited={MapSet.member?(@visited_ids, suggestion.user.id)}
                has_chat={MapSet.member?(@chat_user_ids, suggestion.user.id)}
              />
            <% end %>
          </div>
        </div>

        <%!-- Wildcards Section --%>
        <div :if={!@loading && !@slots_full && !@daily_limit_reached} class="mt-10">
          <div class="divider"></div>

          <div class="flex items-center gap-2 mb-2">
            <.icon name="hero-bolt" class="h-5 w-5 text-accent" />
            <h2 class="text-lg font-semibold">{gettext("Wildcards")}</h2>
          </div>
          <p class="text-sm text-base-content/60 mb-4">
            {gettext("Random picks from your area — no flag matching applied.")}
          </p>

          <%= if @wildcards == [] do %>
            <div class="text-center py-8 text-base-content/40">
              <div class="w-12 h-12 rounded-full bg-base-200 flex items-center justify-center mx-auto mb-3">
                <.icon name="hero-bolt" class="h-6 w-6 opacity-40" />
              </div>
              <p class="text-sm">{gettext("No wildcards available right now")}</p>
              <p class="text-xs mt-1 text-base-content/30">
                {gettext("New wildcards are generated daily — check back tomorrow.")}
              </p>
            </div>
          <% else %>
            <div class={["grid gap-4", ColumnPreferences.grid_class(@columns)]}>
              <.profile_card
                :for={suggestion <- @wildcards}
                suggestion={suggestion}
                variant={:wildcard}
                city_names={@city_names}
                avatar_photos={@avatar_photos}
                story_previews={@story_previews}
                visited={MapSet.member?(@visited_ids, suggestion.user.id)}
                has_chat={MapSet.member?(@chat_user_ids, suggestion.user.id)}
              />
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- Components ---

  defp skeleton_card(assigns) do
    ~H"""
    <div class="skeleton-card rounded-lg overflow-hidden border border-base-300 animate-pulse">
      <div class="bg-base-300 h-48 w-full"></div>
      <div class="p-3 space-y-2">
        <div class="h-4 bg-base-300 rounded w-2/3"></div>
        <div class="h-3 bg-base-300 rounded w-1/2"></div>
        <div class="flex gap-1 mt-2">
          <div class="h-5 bg-base-300 rounded-full w-14"></div>
          <div class="h-5 bg-base-300 rounded-full w-16"></div>
        </div>
        <div class="flex gap-2 mt-3">
          <div class="h-8 bg-base-300 rounded flex-1"></div>
          <div class="h-8 bg-base-300 rounded w-8"></div>
          <div class="h-8 bg-base-300 rounded w-8"></div>
        </div>
      </div>
    </div>
    """
  end

  attr :suggestion, :map, required: true
  attr :variant, :atom, required: true, values: [:match, :wildcard]
  attr :city_names, :map, required: true
  attr :avatar_photos, :map, required: true
  attr :story_previews, :map, default: %{}
  attr :visited, :boolean, default: false
  attr :has_chat, :boolean, default: false

  defp profile_card(assigns) do
    user = assigns.suggestion.user
    avatar = Map.get(assigns.avatar_photos, user.id)
    {_zip_code, city_name} = get_location_info(user, assigns.city_names)
    wildcard? = assigns.variant == :wildcard
    ref = if wildcard?, do: "?ref=wildcard", else: ""

    story_preview =
      case Map.get(assigns.story_previews, user.id) do
        nil -> nil
        content -> content |> strip_markdown() |> String.trim()
      end

    assigns =
      assigns
      |> assign(:user, user)
      |> assign(:avatar, avatar)
      |> assign(:city_name, city_name)
      |> assign(:age, Accounts.compute_age(user.birthday))
      |> assign(:wildcard?, wildcard?)
      |> assign(:profile_path, ~p"/users/#{user.id}" <> ref)
      |> assign(:gender, gender_symbol(user.gender))
      |> assign(:formatted_height, format_height(user.height))
      |> assign(:story_preview, story_preview)

    ~H"""
    <div class={[
      "rounded-lg overflow-hidden transition-shadow hover:shadow-md",
      if(@wildcard?, do: "border-2 border-dashed border-accent/40", else: "border border-base-300")
    ]}>
      <%!-- Photo Area --%>
      <.link navigate={@profile_path} class="block relative">
        <%= if @avatar do %>
          <.live_component
            module={AniminaWeb.LivePhotoComponent}
            id={"#{@variant}-avatar-#{@avatar.id}"}
            photo={@avatar}
            owner?={false}
            variant={:main}
            class="w-full aspect-[4/3] object-cover"
          />
        <% else %>
          <div class={[
            "w-full aspect-[4/3] flex items-center justify-center",
            if(@wildcard?, do: "bg-accent/10", else: "bg-primary/10")
          ]}>
            <div class="text-center">
              <.icon
                name="hero-user"
                class={[
                  "h-12 w-12 mx-auto",
                  if(@wildcard?, do: "text-accent/40", else: "text-primary/40")
                ]}
              />
              <p class={[
                "text-sm font-medium mt-1",
                if(@wildcard?, do: "text-accent/50", else: "text-primary/50")
              ]}>
                {@user.display_name}
              </p>
            </div>
          </div>
        <% end %>

        <%!-- Gradient overlay with name --%>
        <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 to-transparent pt-8 pb-2 px-3">
          <p class="text-white font-semibold text-base drop-shadow-sm">
            {@user.display_name}<span class="font-normal text-white/80">, {@age}</span>
            <span class="text-white/70 ml-1">{@gender}</span>
          </p>
        </div>

        <%!-- Badges --%>
        <div
          :if={@wildcard? || @visited || @has_chat}
          class="absolute top-2 right-2 flex flex-wrap gap-1.5"
        >
          <span
            :if={@wildcard?}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-black/40 text-white backdrop-blur-sm font-medium"
          >
            <.icon name="hero-bolt-mini" class="h-3 w-3" />
            {gettext("Wildcard")}
          </span>
          <span
            :if={@visited}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-black/40 text-white/80 backdrop-blur-sm"
          >
            <.icon name="hero-eye-mini" class="h-3 w-3" />
            {gettext("Visited")}
          </span>
          <span
            :if={@has_chat}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-black/40 text-white backdrop-blur-sm"
          >
            <.icon name="hero-chat-bubble-left-right-mini" class="h-3 w-3" />
            {gettext("Chat")}
          </span>
        </div>
      </.link>

      <%!-- Card Body --%>
      <div class="p-3">
        <%!-- Location + Height + Gender --%>
        <div class="text-sm text-base-content/60 flex items-center gap-1 flex-wrap">
          <span :if={@city_name} class="inline-flex items-center gap-1">
            <.icon name="hero-map-pin-mini" class="h-3 w-3" />
            {@city_name}
          </span>
          <span :if={@city_name && @formatted_height} class="text-base-content/30">&bull;</span>
          <span :if={@formatted_height}>{@formatted_height}</span>
        </div>

        <%!-- Story Preview --%>
        <p :if={@story_preview} class="mt-1.5 text-xs text-base-content/50 line-clamp-2">
          {@story_preview}
        </p>

        <%!-- Shared White Flags (matches only) --%>
        <div
          :if={
            !@wildcard? && @suggestion[:published_white_flags] != nil &&
              @suggestion.published_white_flags != []
          }
          class="mt-2 flex flex-wrap gap-1"
        >
          <span
            :for={flag <- @suggestion.published_white_flags}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-base-200/60 text-base-content/50"
          >
            <span :if={flag.emoji}>{flag.emoji}</span>
            {flag.name}
          </span>
        </div>

        <%!-- Actions --%>
        <div class="mt-3 flex gap-2">
          <.link
            navigate={@profile_path}
            class={[
              "flex-1 btn btn-sm",
              if(@wildcard?, do: "btn-outline btn-accent", else: "btn-primary")
            ]}
          >
            {gettext("View Profile")}
          </.link>
          <button
            phx-click="dismiss"
            phx-value-user-id={@user.id}
            class="btn btn-ghost btn-sm text-base-content/50 hover:text-error"
            title={gettext("Not interested")}
          >
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    default_slot_status = %{active: 0, max: 6, daily_started: 0, daily_max: 2}
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, gettext("Discover"))
      |> assign(:columns, ColumnPreferences.get_columns_for_user(user))
      |> assign(:loading, true)
      |> assign(:matches, [])
      |> assign(:wildcards, [])
      |> assign(:city_names, %{})
      |> assign(:avatar_photos, %{})
      |> assign(:dismissed_count, 0)
      |> assign(:visited_ids, MapSet.new())
      |> assign(:chat_user_ids, MapSet.new())
      |> assign(:story_previews, %{})
      |> assign(:slot_status, default_slot_status)
      |> assign(:slots_full, false)
      |> assign(:daily_limit_reached, false)

    if connected?(socket) do
      send(self(), :load_suggestions)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("device_type_detected", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_columns", %{"columns" => columns_str}, socket) do
    {columns, updated_user} =
      ColumnPreferences.persist_columns(
        socket.assigns.current_scope.user,
        columns_str
      )

    {:noreply,
     socket
     |> assign(:columns, columns)
     |> ColumnPreferences.update_scope_user(updated_user)}
  end

  @impl true
  def handle_event("dismiss", %{"user-id" => user_id}, socket) do
    viewer = socket.assigns.current_scope.user

    case Discovery.dismiss_user_by_id(viewer.id, user_id) do
      {:ok, _} ->
        matches = Enum.reject(socket.assigns.matches, fn s -> s.user.id == user_id end)
        wildcards = Enum.reject(socket.assigns.wildcards, fn s -> s.user.id == user_id end)

        {:noreply,
         socket
         |> assign(:matches, matches)
         |> assign(:wildcards, wildcards)
         |> update(:dismissed_count, &(&1 + 1))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to dismiss user"))}
    end
  end

  @impl true
  def handle_info(:load_suggestions, socket) do
    viewer = socket.assigns.current_scope.user

    # Fetch slot status
    slot_status = Messaging.chat_slot_status(viewer.id)
    slots_full = slot_status.active >= slot_status.max
    daily_limit_reached = !Messaging.can_start_new_chat_today?(viewer.id)

    socket =
      socket
      |> assign(:slot_status, slot_status)
      |> assign(:slots_full, slots_full)
      |> assign(:daily_limit_reached, daily_limit_reached)

    # If slots full or daily limit reached, don't load suggestions
    if slots_full || daily_limit_reached do
      dismissed_count = Discovery.dismissal_count(viewer.id)

      {:noreply,
       socket
       |> assign(:loading, false)
       |> assign(:matches, [])
       |> assign(:wildcards, [])
       |> assign(:dismissed_count, dismissed_count)}
    else
      # Use daily discovery set (static per day)
      all_suggestions = Discovery.get_or_generate_daily_set(viewer)

      # Split into matches and wildcards
      {wildcards, matches} = Enum.split_with(all_suggestions, &(&1.list_type == "wildcard"))

      # Collect all unique users and their data
      all_users = all_suggestions |> Enum.map(& &1.user) |> Enum.uniq_by(& &1.id)
      user_ids = Enum.map(all_users, & &1.id)
      city_names = load_city_names(all_users)
      avatar_photos = AvatarHelpers.load_from_users(all_users)
      story_previews = Moodboard.first_story_content_per_users(user_ids)
      dismissed_count = Discovery.dismissal_count(viewer.id)

      # Load visited and chat indicators
      visited_ids = Discovery.visited_profile_ids(viewer.id, user_ids)
      chat_user_ids = Messaging.conversation_user_ids(viewer.id, user_ids)

      # Enrich combined suggestions with published white flags, drop soft-red conflicts
      enriched_matches =
        matches
        |> enrich_with_published_white_flags(viewer, all_users)
        |> Enum.reject(& &1.has_soft_red)

      {:noreply,
       socket
       |> assign(:loading, false)
       |> assign(:matches, enriched_matches)
       |> assign(:wildcards, wildcards)
       |> assign(:city_names, city_names)
       |> assign(:avatar_photos, avatar_photos)
       |> assign(:story_previews, story_previews)
       |> assign(:dismissed_count, dismissed_count)
       |> assign(:visited_ids, visited_ids)
       |> assign(:chat_user_ids, chat_user_ids)}
    end
  end

  # --- Private Functions ---

  defp load_city_names(users) do
    users
    |> Enum.flat_map(fn user ->
      case user.locations do
        locations when is_list(locations) -> locations
        _ -> []
      end
    end)
    |> GeoData.city_names_for_locations()
  end

  defp format_height(nil), do: nil

  defp format_height(cm) when is_integer(cm) do
    meters = div(cm, 100)
    remainder = rem(cm, 100)
    "#{meters},#{String.pad_leading(Integer.to_string(remainder), 2, "0")} m"
  end

  defp enrich_with_published_white_flags(suggestions, viewer, all_users) do
    # Collect all white_white flag IDs across suggestions
    all_flag_ids =
      suggestions
      |> Enum.flat_map(& &1.white_white_flag_ids)
      |> Enum.uniq()

    # Batch-load flag details (with categories)
    flags_by_id =
      case all_flag_ids do
        [] -> %{}
        ids -> ids |> Traits.list_flags_by_ids() |> Map.new(&{&1.id, &1})
      end

    # Load published category IDs for viewer and all candidates
    viewer_published = MapSet.new(Traits.list_published_white_flag_category_ids(viewer))

    published_by_user =
      all_users
      |> Map.new(fn user ->
        {user.id, MapSet.new(Traits.list_published_white_flag_category_ids(user))}
      end)

    # Enrich each suggestion with published white flags only
    Enum.map(suggestions, fn suggestion ->
      candidate_published = Map.get(published_by_user, suggestion.user.id, MapSet.new())

      published_flags =
        suggestion.white_white_flag_ids
        |> Enum.map(&Map.get(flags_by_id, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn flag ->
          MapSet.member?(viewer_published, flag.category_id) &&
            MapSet.member?(candidate_published, flag.category_id)
        end)

      Map.put(suggestion, :published_white_flags, published_flags)
    end)
  end
end
