defmodule AniminaWeb.SpotlightLive do
  @moduledoc """
  LiveView for the Daily Spotlight page.

  Shows 6 candidates from the spotlight pool (round-robin) plus 2 wildcards
  from an expanded pool, seeded once per day and stable until Berlin midnight.
  """

  use AniminaWeb, :live_view

  import AniminaWeb.Helpers.UserHelpers, only: [get_location_info: 2, gender_symbol: 1]

  alias Animina.Accounts
  alias Animina.Discovery
  alias Animina.Discovery.Spotlight
  alias Animina.GeoData
  alias Animina.Messaging
  alias Animina.Moodboard
  alias AniminaWeb.Helpers.AvatarHelpers

  @countdown_interval :timer.minutes(1)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto">
        <%!-- Breadcrumbs --%>
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>{gettext("Spotlight")}</li>
          </ul>
        </div>

        <%!-- Header with conversations toggle --%>
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <.icon name="hero-sparkles" class="h-6 w-6 text-accent" />
            <h1 class="text-2xl font-bold">{gettext("Daily Spotlight")}</h1>
          </div>

          <button phx-click="toggle_conversations" class="btn btn-circle btn-ghost relative">
            <.icon name="hero-chat-bubble-left-right" class="h-6 w-6" />
            <span
              :if={@unread_count > 0}
              class="badge badge-xs badge-error absolute -top-1 -right-1"
            >
              {@unread_count}
            </span>
          </button>
        </div>

        <%!-- Countdown timer --%>
        <p class="text-sm text-base-content/50 mb-6">
          {gettext("New profiles in %{time}", time: @countdown_text)}
        </p>

        <%!-- Loading state --%>
        <div :if={@loading} class="flex justify-center py-12">
          <span class="loading loading-spinner loading-lg text-primary"></span>
        </div>

        <%!-- Spotlight cards --%>
        <div :if={!@loading}>
          <div :if={@candidates == []} class="text-center py-12 text-base-content/50">
            <.icon name="hero-magnifying-glass" class="h-12 w-12 mx-auto mb-3 opacity-40" />
            <p>{gettext("No candidates found. Try adjusting your search settings.")}</p>
          </div>

          <div :if={@candidates != []} class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
            <.spotlight_card
              :for={candidate <- @candidates}
              candidate={candidate}
              avatar={Map.get(@avatar_photos, candidate.id)}
              city_name={city_name_for(candidate, @city_names)}
              story_excerpt={Map.get(@first_stories, candidate.id)}
              wildcard?={MapSet.member?(@wildcard_ids, candidate.id)}
              visited?={MapSet.member?(@visited_ids, candidate.id)}
            />
          </div>
        </div>
      </div>

      <%!-- Conversations sidebar --%>
      <.live_component
        :if={@sidebar_open}
        module={AniminaWeb.ConversationsSidebarComponent}
        id="conversations-sidebar"
        current_user_id={@current_scope.user.id}
        conversations={@conversations}
        avatar_photos={@conversation_avatars}
      />
    </Layouts.app>
    """
  end

  attr :candidate, :map, required: true
  attr :avatar, :map, default: nil
  attr :city_name, :string, default: nil
  attr :story_excerpt, :string, default: nil
  attr :wildcard?, :boolean, default: false
  attr :visited?, :boolean, default: false

  defp spotlight_card(assigns) do
    assigns =
      assigns
      |> assign(:age, Accounts.compute_age(assigns.candidate.birthday))
      |> assign(:gender, gender_symbol(assigns.candidate.gender))
      |> assign(:truncated_story, truncate_story(assigns.story_excerpt))

    ~H"""
    <div class={[
      "rounded-lg overflow-hidden hover:shadow-md transition-shadow",
      if(@wildcard?,
        do: "border-2 border-accent/50",
        else: "border border-base-300"
      )
    ]}>
      <.link
        navigate={~p"/users/#{@candidate.id}" <> if(@wildcard?, do: "?ref=wildcard", else: "")}
        class="block relative"
      >
        <%= if @avatar do %>
          <.live_component
            module={AniminaWeb.LivePhotoComponent}
            id={"spotlight-avatar-#{@avatar.id}"}
            photo={@avatar}
            owner?={false}
            variant={:main}
            class="w-full aspect-[4/3] object-cover"
          />
        <% else %>
          <div class="w-full aspect-[4/3] bg-base-200 flex items-center justify-center">
            <.icon name="hero-user" class="h-10 w-10 text-base-content/30" />
          </div>
        <% end %>

        <%!-- Wildcard badge --%>
        <span
          :if={@wildcard?}
          class="absolute top-2 right-2 badge badge-accent badge-sm gap-1"
        >
          <.icon name="hero-bolt-mini" class="h-3 w-3" /> {gettext("Wildcard")}
        </span>

        <%!-- Visited badge --%>
        <span
          :if={@visited?}
          class="absolute top-2 left-2 badge badge-ghost badge-sm bg-black/40 text-white/80 border-0"
        >
          <.icon name="hero-eye-mini" class="h-3 w-3" /> {gettext("Visited")}
        </span>

        <%!-- Name/age overlay --%>
        <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 to-transparent pt-8 pb-2 px-3">
          <p class="text-white font-semibold text-sm drop-shadow-sm">
            {@candidate.display_name}<span :if={@age} class="font-normal text-white/80">, {@age}</span>
            <span class="text-white/70 ml-1">{@gender}</span>
          </p>
        </div>
      </.link>

      <div class="p-2">
        <p :if={@city_name} class="text-xs text-base-content/50 flex items-center gap-1">
          <.icon name="hero-map-pin-mini" class="h-3 w-3" />
          {@city_name}
        </p>
        <p :if={@truncated_story} class="text-xs text-base-content/60 mt-1 line-clamp-2">
          {@truncated_story}
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    viewer = socket.assigns.current_scope.user

    countdown_text = Spotlight.format_countdown(Spotlight.seconds_until_midnight())

    socket =
      socket
      |> assign(:page_title, gettext("Daily Spotlight"))
      |> assign(:loading, true)
      |> assign(:candidates, [])
      |> assign(:wildcard_ids, MapSet.new())
      |> assign(:avatar_photos, %{})
      |> assign(:city_names, %{})
      |> assign(:first_stories, %{})
      |> assign(:visited_ids, MapSet.new())
      |> assign(:countdown_text, countdown_text)
      |> assign(:sidebar_open, false)
      |> assign(:conversations, [])
      |> assign(:conversation_avatars, %{})
      |> assign(:unread_count, 0)

    if connected?(socket) do
      send(self(), :load_spotlight)
      schedule_countdown_tick()

      # Subscribe to message events for unread count
      Phoenix.PubSub.subscribe(Animina.PubSub, Messaging.user_topic(viewer.id))
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_conversations", _params, socket) do
    sidebar_open = !socket.assigns.sidebar_open

    socket =
      if sidebar_open && socket.assigns.conversations == [] do
        load_conversations(socket)
      else
        socket
      end

    {:noreply, assign(socket, :sidebar_open, sidebar_open)}
  end

  @impl true
  def handle_info(:load_spotlight, socket) do
    viewer = socket.assigns.current_scope.user

    {candidates, wildcard_ids} = Spotlight.get_or_seed_daily(viewer)

    candidate_ids = Enum.map(candidates, & &1.id)

    # Load supporting data
    avatar_photos = AvatarHelpers.load_from_users(candidates)
    city_names = load_city_names(candidates)
    first_stories = Moodboard.first_story_content_per_users(candidate_ids)
    visited_ids = Discovery.visited_profile_ids(viewer.id, candidate_ids)
    unread_count = Messaging.unread_count(viewer.id)

    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:candidates, candidates)
     |> assign(:wildcard_ids, wildcard_ids)
     |> assign(:avatar_photos, avatar_photos)
     |> assign(:city_names, city_names)
     |> assign(:first_stories, first_stories)
     |> assign(:visited_ids, visited_ids)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_info(:countdown_tick, socket) do
    seconds = Spotlight.seconds_until_midnight()

    socket =
      if seconds <= 0 do
        # Midnight passed — reload spotlight
        send(self(), :load_spotlight)
        assign(socket, :countdown_text, Spotlight.format_countdown(0))
      else
        assign(socket, :countdown_text, Spotlight.format_countdown(seconds))
      end

    schedule_countdown_tick()
    {:noreply, socket}
  end

  # Unread count changed
  @impl true
  def handle_info({:unread_count_changed, count}, socket) do
    socket = assign(socket, :unread_count, count)

    # Reload conversations if sidebar is open
    socket =
      if socket.assigns.sidebar_open do
        load_conversations(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  # New message — update sidebar if open
  @impl true
  def handle_info({:new_message, _conversation_id, _message}, socket) do
    socket =
      if socket.assigns.sidebar_open do
        load_conversations(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  # Conversation closed/reopened — refresh sidebar
  @impl true
  def handle_info({event, _conversation_id}, socket)
      when event in [:conversation_closed, :conversation_reopened] do
    socket =
      if socket.assigns.sidebar_open do
        load_conversations(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  # Catch-all for other PubSub messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # --- Private helpers ---

  defp schedule_countdown_tick do
    Process.send_after(self(), :countdown_tick, @countdown_interval)
  end

  defp load_conversations(socket) do
    user_id = socket.assigns.current_scope.user.id
    conversations = Messaging.list_conversations(user_id)
    avatars = AvatarHelpers.load_from_conversations(conversations)

    assign(socket,
      conversations: conversations,
      conversation_avatars: avatars
    )
  end

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

  defp city_name_for(user, city_names) do
    {_zip, name} = get_location_info(user, city_names)
    name
  end

  defp truncate_story(nil), do: nil

  defp truncate_story(text) do
    # Strip markdown and truncate
    text
    |> String.replace(~r/[#*_~`>\[\]()]/, "")
    |> String.trim()
    |> String.slice(0, 80)
  end
end
