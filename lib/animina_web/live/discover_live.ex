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

  alias Animina.Discovery
  alias Animina.GeoData
  alias Animina.Messaging
  alias Animina.Photos
  alias Animina.Traits

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto">
        <div class="text-center mb-8">
          <.header>
            {gettext("Discover")}
            <:subtitle>{gettext("Partner suggestions based on your preferences")}</:subtitle>
          </.header>
        </div>

        <%!-- Your Matches Section --%>
        <div class="mb-8">
          <div class="flex items-center gap-2 mb-2">
            <.icon name="hero-sparkles" class="h-5 w-5 text-primary" />
            <h2 class="text-lg font-semibold">{gettext("Your Matches")}</h2>
          </div>
          <p class="text-sm text-base-content/60 mb-4">
            {gettext("Smart suggestions based on your preferences and compatibility")}
          </p>

          <%!-- Column Toggle --%>
          <div class="flex justify-end mb-4">
            <div class="btn-group">
              <button
                type="button"
                phx-click="change_columns"
                phx-value-columns="1"
                class={["btn btn-sm", @columns == 1 && "btn-active"]}
                aria-label={gettext("Single column")}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <rect x="6" y="3" width="12" height="18" rx="1" stroke-width="2" />
                </svg>
              </button>
              <button
                type="button"
                phx-click="change_columns"
                phx-value-columns="2"
                class={["btn btn-sm", @columns == 2 && "btn-active"]}
                aria-label={gettext("Two columns")}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <rect x="3" y="3" width="7" height="18" rx="1" stroke-width="2" />
                  <rect x="14" y="3" width="7" height="18" rx="1" stroke-width="2" />
                </svg>
              </button>
              <button
                type="button"
                phx-click="change_columns"
                phx-value-columns="3"
                class={["btn btn-sm", @columns == 3 && "btn-active"]}
                aria-label={gettext("Three columns")}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <rect x="2" y="3" width="5" height="18" rx="1" stroke-width="2" />
                  <rect x="9.5" y="3" width="5" height="18" rx="1" stroke-width="2" />
                  <rect x="17" y="3" width="5" height="18" rx="1" stroke-width="2" />
                </svg>
              </button>
            </div>
          </div>

          <%!-- Matches Grid --%>
          <div class={[
            "grid gap-4",
            case @columns do
              1 -> "grid-cols-1"
              2 -> "grid-cols-1 sm:grid-cols-2"
              3 -> "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
            end
          ]}>
            <%= if Enum.empty?(@matches) do %>
              <div class="col-span-full text-center py-12 text-base-content/50">
                <.icon name="hero-magnifying-glass" class="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p class="text-lg">{gettext("No suggestions available")}</p>
                <p class="text-sm mt-2">
                  {gettext("Check back later or adjust your preferences")}
                </p>
                <button
                  phx-click="refresh"
                  class="btn btn-primary btn-sm mt-4"
                >
                  <.icon name="hero-arrow-path" class="h-4 w-4" />
                  {gettext("Refresh")}
                </button>
              </div>
            <% else %>
              <.suggestion_card
                :for={suggestion <- @matches}
                suggestion={suggestion}
                city_names={@city_names}
                avatar_photos={@avatar_photos}
                visited={MapSet.member?(@visited_ids, suggestion.user.id)}
                has_chat={MapSet.member?(@chat_user_ids, suggestion.user.id)}
              />
            <% end %>
          </div>
        </div>

        <%!-- Wildcards Section --%>
        <div class="mt-10">
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
              <.icon name="hero-bolt" class="h-8 w-8 mx-auto mb-2 opacity-40" />
              <p class="text-sm">{gettext("No wildcards available right now")}</p>
            </div>
          <% else %>
            <div class={[
              "grid gap-4",
              case @columns do
                1 -> "grid-cols-1"
                2 -> "grid-cols-1 sm:grid-cols-2"
                3 -> "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
              end
            ]}>
              <.wildcard_card
                :for={suggestion <- @wildcards}
                suggestion={suggestion}
                city_names={@city_names}
                avatar_photos={@avatar_photos}
                visited={MapSet.member?(@visited_ids, suggestion.user.id)}
                has_chat={MapSet.member?(@chat_user_ids, suggestion.user.id)}
              />
            </div>
          <% end %>
        </div>

        <%!-- Stats Footer --%>
        <div class="mt-6 text-center text-xs text-base-content/40">
          {gettext("%{dismissed} dismissed",
            dismissed: @dismissed_count
          )}
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :suggestion, :map, required: true
  attr :city_names, :map, required: true
  attr :avatar_photos, :map, required: true
  attr :visited, :boolean, default: false
  attr :has_chat, :boolean, default: false

  defp suggestion_card(assigns) do
    user = assigns.suggestion.user
    avatar = Map.get(assigns.avatar_photos, user.id)
    {zip_code, city_name} = get_location_info(user, assigns.city_names)

    assigns =
      assigns
      |> assign(:user, user)
      |> assign(:avatar, avatar)
      |> assign(:zip_code, zip_code)
      |> assign(:city_name, city_name)
      |> assign(:age, compute_age(user.birthday))

    ~H"""
    <div class="rounded-lg border border-base-300 overflow-hidden transition-shadow hover:shadow-md">
      <div class="p-4 relative">
        <%!-- Visited / Chat indicators --%>
        <div :if={@visited || @has_chat} class="absolute top-2 right-2 flex flex-wrap gap-1.5">
          <span
            :if={@visited}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-base-200 text-base-content/50"
          >
            <.icon name="hero-eye-mini" class="h-3 w-3" />
            {gettext("Visited")}
          </span>
          <span
            :if={@has_chat}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-info/10 text-info"
          >
            <.icon name="hero-chat-bubble-left-right-mini" class="h-3 w-3" />
            {gettext("Chat")}
          </span>
        </div>

        <%!-- User Info Row --%>
        <div class="flex items-start gap-4">
          <%!-- Avatar --%>
          <.link navigate={~p"/moodboard/#{@user.id}"} class="flex-shrink-0">
            <%= if @avatar do %>
              <.live_component
                module={AniminaWeb.LivePhotoComponent}
                id={"avatar-#{@avatar.id}"}
                photo={@avatar}
                owner?={false}
                variant={:thumbnail}
                class="w-16 h-16 rounded-lg object-cover"
              />
            <% else %>
              <div class="w-16 h-16 rounded-lg bg-primary/10 flex items-center justify-center">
                <.icon name={gender_icon(@user.gender)} class="h-8 w-8 text-primary/60" />
              </div>
            <% end %>
          </.link>

          <%!-- Info --%>
          <div class="flex-1 min-w-0">
            <.link
              navigate={~p"/moodboard/#{@user.id}"}
              class="font-semibold text-base-content hover:text-primary transition-colors"
            >
              {@user.display_name}
            </.link>
            <div class="text-sm text-base-content/60 mt-0.5">
              {gettext("%{age} years", age: @age)}
              <span :if={@user.height} class="mx-1">&bull;</span>
              <span :if={@user.height}>{@user.height} cm</span>
            </div>
            <div
              :if={@city_name || @zip_code}
              class="text-sm text-base-content/50 mt-0.5 flex items-center gap-1"
            >
              <.icon name="hero-map-pin-mini" class="h-3 w-3" />
              <span class="whitespace-nowrap">
                <span :if={@zip_code}>{@zip_code}</span>
                <span :if={@city_name}>{@city_name}</span>
              </span>
            </div>
          </div>
        </div>

        <%!-- Shared White Flags --%>
        <div :if={@suggestion.published_white_flags != []} class="mt-2 flex flex-wrap gap-1">
          <span
            :for={flag <- @suggestion.published_white_flags}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-base-200/60 text-base-content/50"
          >
            <span :if={flag.emoji}>{flag.emoji}</span>
            {flag.name}
          </span>
        </div>

        <%!-- Actions --%>
        <div class="mt-4 flex gap-2">
          <.link
            navigate={~p"/moodboard/#{@user.id}"}
            class="flex-1 btn btn-primary btn-sm"
          >
            {gettext("View Profile")}
          </.link>
          <.link
            navigate={~p"/messages?start_with=#{@user.id}"}
            class="btn btn-ghost btn-sm"
            title={gettext("Send message")}
          >
            <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
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

  attr :suggestion, :map, required: true
  attr :city_names, :map, required: true
  attr :avatar_photos, :map, required: true
  attr :visited, :boolean, default: false
  attr :has_chat, :boolean, default: false

  defp wildcard_card(assigns) do
    user = assigns.suggestion.user
    avatar = Map.get(assigns.avatar_photos, user.id)
    {zip_code, city_name} = get_location_info(user, assigns.city_names)

    assigns =
      assigns
      |> assign(:user, user)
      |> assign(:avatar, avatar)
      |> assign(:zip_code, zip_code)
      |> assign(:city_name, city_name)
      |> assign(:age, compute_age(user.birthday))

    ~H"""
    <div class="rounded-lg border-2 border-dashed border-accent/40 overflow-hidden transition-shadow hover:shadow-md">
      <div class="p-4 relative">
        <%!-- Wildcard / Visited / Chat indicators --%>
        <div class="absolute top-2 right-2 flex flex-wrap gap-1.5">
          <span class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-accent/10 text-accent font-medium">
            <.icon name="hero-bolt-mini" class="h-3 w-3" />
            {gettext("Wildcard")}
          </span>
          <span
            :if={@visited}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-base-200 text-base-content/50"
          >
            <.icon name="hero-eye-mini" class="h-3 w-3" />
            {gettext("Visited")}
          </span>
          <span
            :if={@has_chat}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-info/10 text-info"
          >
            <.icon name="hero-chat-bubble-left-right-mini" class="h-3 w-3" />
            {gettext("Chat")}
          </span>
        </div>

        <%!-- User Info Row --%>
        <div class="flex items-start gap-4">
          <%!-- Avatar --%>
          <.link navigate={~p"/moodboard/#{@user.id}?ref=wildcard"} class="flex-shrink-0">
            <%= if @avatar do %>
              <.live_component
                module={AniminaWeb.LivePhotoComponent}
                id={"wildcard-avatar-#{@avatar.id}"}
                photo={@avatar}
                owner?={false}
                variant={:thumbnail}
                class="w-16 h-16 rounded-lg object-cover"
              />
            <% else %>
              <div class="w-16 h-16 rounded-lg bg-accent/10 flex items-center justify-center">
                <.icon name={gender_icon(@user.gender)} class="h-8 w-8 text-accent/60" />
              </div>
            <% end %>
          </.link>

          <%!-- Info --%>
          <div class="flex-1 min-w-0">
            <.link
              navigate={~p"/moodboard/#{@user.id}?ref=wildcard"}
              class="font-semibold text-base-content hover:text-accent transition-colors"
            >
              {@user.display_name}
            </.link>
            <div class="text-sm text-base-content/60 mt-0.5">
              {gettext("%{age} years", age: @age)}
              <span :if={@user.height} class="mx-1">&bull;</span>
              <span :if={@user.height}>{@user.height} cm</span>
            </div>
            <div
              :if={@city_name || @zip_code}
              class="text-sm text-base-content/50 mt-0.5 flex items-center gap-1"
            >
              <.icon name="hero-map-pin-mini" class="h-3 w-3" />
              <span class="whitespace-nowrap">
                <span :if={@zip_code}>{@zip_code}</span>
                <span :if={@city_name}>{@city_name}</span>
              </span>
            </div>
          </div>
        </div>

        <%!-- Actions --%>
        <div class="mt-4 flex gap-2">
          <.link
            navigate={~p"/moodboard/#{@user.id}?ref=wildcard"}
            class="flex-1 btn btn-outline btn-accent btn-sm"
          >
            {gettext("View Profile")}
          </.link>
          <.link
            navigate={~p"/messages?start_with=#{@user.id}"}
            class="btn btn-ghost btn-sm"
            title={gettext("Send message")}
          >
            <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
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
    socket =
      socket
      |> assign(:page_title, gettext("Discover"))
      |> assign(:columns, 2)
      |> assign(:loading, true)
      |> assign(:matches, [])
      |> assign(:wildcards, [])
      |> assign(:city_names, %{})
      |> assign(:avatar_photos, %{})
      |> assign(:dismissed_count, 0)
      |> assign(:visited_ids, MapSet.new())
      |> assign(:chat_user_ids, MapSet.new())

    if connected?(socket) do
      send(self(), :load_suggestions)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("change_columns", %{"columns" => columns_str}, socket) do
    columns = String.to_integer(columns_str)
    {:noreply, assign(socket, :columns, columns)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    send(self(), :load_suggestions)
    {:noreply, assign(socket, :loading, true)}
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

    # Generate combined suggestions (the only curated list now)
    combined = Discovery.generate_combined_suggestions(viewer)

    # Generate wildcards, excluding users already in the combined list
    combined_user_ids = Enum.map(combined, & &1.user.id)
    wildcards = Discovery.generate_wildcards(viewer, combined_user_ids)

    # Collect all unique users and their data
    all_suggestions = combined ++ wildcards
    all_users = all_suggestions |> Enum.map(& &1.user) |> Enum.uniq_by(& &1.id)
    user_ids = Enum.map(all_users, & &1.id)
    city_names = load_city_names(all_users)
    avatar_photos = load_avatar_photos(all_users)
    dismissed_count = Discovery.dismissal_count(viewer.id)

    # Load visited and chat indicators
    visited_ids = Discovery.visited_profile_ids(viewer.id, user_ids)
    chat_user_ids = Messaging.conversation_user_ids(viewer.id, user_ids)

    # Enrich combined suggestions with published white flags, drop soft-red conflicts
    enriched_combined =
      combined
      |> enrich_with_published_white_flags(viewer, all_users)
      |> Enum.reject(& &1.has_soft_red)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:matches, enriched_combined)
      |> assign(:wildcards, wildcards)
      |> assign(:city_names, city_names)
      |> assign(:avatar_photos, avatar_photos)
      |> assign(:dismissed_count, dismissed_count)
      |> assign(:visited_ids, visited_ids)
      |> assign(:chat_user_ids, chat_user_ids)

    {:noreply, socket}
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

  defp load_avatar_photos(users) do
    users
    |> Enum.map(fn user ->
      {user.id, Photos.get_user_avatar(user.id)}
    end)
    |> Enum.reject(fn {_id, photo} -> is_nil(photo) end)
    |> Map.new()
  end

  defp get_location_info(user, city_names) do
    case user.locations do
      [%{zip_code: zip} | _] -> {zip, Map.get(city_names, zip)}
      _ -> {nil, nil}
    end
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

  defp compute_age(nil), do: nil

  defp compute_age(birthday) do
    today = Date.utc_today()
    age = today.year - birthday.year

    if {today.month, today.day} < {birthday.month, birthday.day},
      do: age - 1,
      else: age
  end

  defp gender_icon("male"), do: "hero-user"
  defp gender_icon("female"), do: "hero-user"
  defp gender_icon("diverse"), do: "hero-user"
  defp gender_icon(_), do: "hero-user"
end
