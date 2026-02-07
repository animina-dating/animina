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

  import AniminaWeb.Helpers.UserHelpers, only: [get_location_info: 2]

  alias Animina.Accounts
  alias Animina.Discovery
  alias Animina.GeoData
  alias Animina.Messaging
  alias Animina.Traits
  alias AniminaWeb.ColumnToggle
  alias AniminaWeb.Helpers.AvatarHelpers

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

        <%!-- Info Panel --%>
        <div class="bg-base-200/50 rounded-lg p-4 mb-6 text-sm text-base-content/70">
          <div class="flex items-start gap-3">
            <.icon name="hero-information-circle" class="h-5 w-5 text-info flex-shrink-0 mt-0.5" />
            <div>
              <p class="font-medium text-base-content mb-1">{gettext("How Discovery Works")}</p>
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
          </div>
        </div>

        <%!-- Slot Status Bar --%>
        <div :if={@slot_status} class="flex flex-wrap gap-3 mb-6 justify-center">
          <div class="badge badge-lg badge-outline gap-2">
            <.icon name="hero-chat-bubble-left-right-mini" class="h-4 w-4" />
            {gettext("%{active}/%{max} active chats",
              active: @slot_status.active,
              max: @slot_status.max
            )}
          </div>
          <div class="badge badge-lg badge-outline gap-2">
            <.icon name="hero-plus-circle-mini" class="h-4 w-4" />
            {gettext("%{remaining} new chats remaining today",
              remaining: max(@slot_status.daily_max - @slot_status.daily_started, 0)
            )}
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
        <div :if={!@slots_full && !@daily_limit_reached} class="mb-8">
          <div class="flex items-center gap-2 mb-2">
            <.icon name="hero-sparkles" class="h-5 w-5 text-primary" />
            <h2 class="text-lg font-semibold">{gettext("Your Matches")}</h2>
          </div>
          <p class="text-sm text-base-content/60 mb-4">
            {gettext("Smart suggestions based on your preferences and compatibility")}
          </p>

          <%!-- Column Toggle --%>
          <ColumnToggle.column_toggle columns={@columns} />

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
              </div>
            <% else %>
              <.profile_card
                :for={suggestion <- @matches}
                suggestion={suggestion}
                variant={:match}
                city_names={@city_names}
                avatar_photos={@avatar_photos}
                visited={MapSet.member?(@visited_ids, suggestion.user.id)}
                has_chat={MapSet.member?(@chat_user_ids, suggestion.user.id)}
                can_message={!@slots_full}
              />
            <% end %>
          </div>
        </div>

        <%!-- Wildcards Section --%>
        <div :if={!@slots_full && !@daily_limit_reached} class="mt-10">
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
              <.profile_card
                :for={suggestion <- @wildcards}
                suggestion={suggestion}
                variant={:wildcard}
                city_names={@city_names}
                avatar_photos={@avatar_photos}
                visited={MapSet.member?(@visited_ids, suggestion.user.id)}
                has_chat={MapSet.member?(@chat_user_ids, suggestion.user.id)}
                can_message={!@slots_full}
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
  attr :variant, :atom, required: true, values: [:match, :wildcard]
  attr :city_names, :map, required: true
  attr :avatar_photos, :map, required: true
  attr :visited, :boolean, default: false
  attr :has_chat, :boolean, default: false
  attr :can_message, :boolean, default: true

  defp profile_card(assigns) do
    user = assigns.suggestion.user
    avatar = Map.get(assigns.avatar_photos, user.id)
    {zip_code, city_name} = get_location_info(user, assigns.city_names)
    wildcard? = assigns.variant == :wildcard
    ref = if wildcard?, do: "?ref=wildcard", else: ""

    assigns =
      assigns
      |> assign(:user, user)
      |> assign(:avatar, avatar)
      |> assign(:zip_code, zip_code)
      |> assign(:city_name, city_name)
      |> assign(:age, Accounts.compute_age(user.birthday))
      |> assign(:wildcard?, wildcard?)
      |> assign(:profile_path, ~p"/moodboard/#{user.id}" <> ref)

    ~H"""
    <div class={[
      "rounded-lg overflow-hidden transition-shadow hover:shadow-md",
      if(@wildcard?, do: "border-2 border-dashed border-accent/40", else: "border border-base-300")
    ]}>
      <div class="p-4 relative">
        <%!-- Indicators --%>
        <div
          :if={@wildcard? || @visited || @has_chat}
          class="absolute top-2 right-2 flex flex-wrap gap-1.5"
        >
          <span
            :if={@wildcard?}
            class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-accent/10 text-accent font-medium"
          >
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
          <.link navigate={@profile_path} class="flex-shrink-0">
            <%= if @avatar do %>
              <.live_component
                module={AniminaWeb.LivePhotoComponent}
                id={"#{@variant}-avatar-#{@avatar.id}"}
                photo={@avatar}
                owner?={false}
                variant={:thumbnail}
                class="w-16 h-16 rounded-lg object-cover"
              />
            <% else %>
              <div class={[
                "w-16 h-16 rounded-lg flex items-center justify-center",
                if(@wildcard?, do: "bg-accent/10", else: "bg-primary/10")
              ]}>
                <.icon
                  name="hero-user"
                  class={["h-8 w-8", if(@wildcard?, do: "text-accent/60", else: "text-primary/60")]}
                />
              </div>
            <% end %>
          </.link>

          <div class="flex-1 min-w-0">
            <.link
              navigate={@profile_path}
              class={[
                "font-semibold text-base-content transition-colors",
                if(@wildcard?, do: "hover:text-accent", else: "hover:text-primary")
              ]}
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
        <div class="mt-4 flex gap-2">
          <.link
            navigate={@profile_path}
            class={[
              "flex-1 btn btn-sm",
              if(@wildcard?, do: "btn-outline btn-accent", else: "btn-primary")
            ]}
          >
            {gettext("View Profile")}
          </.link>
          <%= if @can_message do %>
            <.link
              navigate={~p"/messages?start_with=#{@user.id}"}
              class="btn btn-ghost btn-sm"
              title={gettext("Send message")}
            >
              <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
            </.link>
          <% else %>
            <span
              class="btn btn-ghost btn-sm btn-disabled opacity-50"
              title={gettext("No free chat slots")}
            >
              <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" />
            </span>
          <% end %>
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
      |> assign(:slot_status, default_slot_status)
      |> assign(:slots_full, false)
      |> assign(:daily_limit_reached, false)

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
