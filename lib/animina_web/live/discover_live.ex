defmodule AniminaWeb.DiscoverLive do
  @moduledoc """
  LiveView for discovering potential matches.

  Shows a grid of the final candidates with avatars and white flag badges,
  plus a pool count showing how many users are in the viewer's area.
  """

  use AniminaWeb, :live_view

  import AniminaWeb.Helpers.UserHelpers, only: [get_location_info: 2, gender_symbol: 1]

  alias Animina.Accounts
  alias Animina.Discovery.CandidatePool
  alias Animina.GeoData
  alias Animina.Traits
  alias AniminaWeb.Helpers.AvatarHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto">
        <div class="flex items-center gap-2 mb-6">
          <.icon name="hero-sparkles" class="h-6 w-6 text-accent" />
          <h1 class="text-2xl font-bold">{gettext("Discover")}</h1>
        </div>

        <%!-- Loading state --%>
        <div :if={@loading} class="flex justify-center py-12">
          <span class="loading loading-spinner loading-lg text-primary"></span>
        </div>

        <%!-- Results Section --%>
        <div :if={!@loading}>
          <h2 class="text-lg font-semibold mb-3 flex items-center gap-2">
            <.icon name="hero-user-group" class="h-5 w-5 text-primary" /> {gettext("Candidates")}
            <span class="badge badge-neutral badge-sm">{length(@candidates)}</span>
            <span class="text-sm font-normal text-base-content/50">
              {gettext("from %{count} in your area", count: @pool_count)}
            </span>
          </h2>

          <div :if={@candidates == []} class="text-center py-12 text-base-content/50">
            <.icon name="hero-magnifying-glass" class="h-12 w-12 mx-auto mb-3 opacity-40" />
            <p>No candidates match all filters.</p>
          </div>

          <div :if={@candidates != []} class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
            <.candidate_card
              :for={candidate <- @candidates}
              candidate={candidate}
              avatar={Map.get(@avatar_photos, candidate.id)}
              city_name={city_name_for(candidate, @city_names)}
              white_flags={Map.get(@white_flags_by_user, candidate.id, [])}
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :candidate, :map, required: true
  attr :avatar, :map, default: nil
  attr :city_name, :string, default: nil
  attr :white_flags, :list, default: []

  defp candidate_card(assigns) do
    assigns =
      assigns
      |> assign(:age, Accounts.compute_age(assigns.candidate.birthday))
      |> assign(:gender, gender_symbol(assigns.candidate.gender))

    ~H"""
    <div class="rounded-lg overflow-hidden border border-base-300 hover:shadow-md transition-shadow">
      <.link navigate={~p"/users/#{@candidate.id}"} class="block relative">
        <%= if @avatar do %>
          <.live_component
            module={AniminaWeb.LivePhotoComponent}
            id={"discover-avatar-#{@avatar.id}"}
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
        <div :if={@white_flags != []} class="mt-1.5 flex flex-wrap gap-1">
          <span
            :for={flag <- Enum.take(@white_flags, 5)}
            class="inline-flex items-center gap-0.5 text-xs px-1.5 py-0.5 rounded-full bg-base-200/60 text-base-content/50"
          >
            <span :if={flag.emoji}>{flag.emoji}</span>
            {flag.name}
          </span>
          <span
            :if={length(@white_flags) > 5}
            class="text-xs text-base-content/40"
          >
            +{length(@white_flags) - 5}
          </span>
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
      |> assign(:loading, true)
      |> assign(:pool_count, 0)
      |> assign(:candidates, [])
      |> assign(:avatar_photos, %{})
      |> assign(:city_names, %{})
      |> assign(:white_flags_by_user, %{})

    if connected?(socket) do
      send(self(), :load_results)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_results, socket) do
    viewer = socket.assigns.current_scope.user

    {pool_count, candidates} = CandidatePool.build_with_pool_count(viewer)

    # Preload locations for city name display
    candidates = Animina.Repo.preload(candidates, :locations)

    # Load supporting data
    avatar_photos = AvatarHelpers.load_from_users(candidates)
    city_names = load_city_names(candidates)
    white_flags_by_user = load_white_flags(candidates)

    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:pool_count, pool_count)
     |> assign(:candidates, candidates)
     |> assign(:avatar_photos, avatar_photos)
     |> assign(:city_names, city_names)
     |> assign(:white_flags_by_user, white_flags_by_user)}
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

  defp load_white_flags(users) do
    users
    |> Map.new(fn user ->
      flags =
        user
        |> Traits.list_user_flags("white")
        |> Enum.map(& &1.flag)

      {user.id, flags}
    end)
  end

  defp city_name_for(user, city_names) do
    {_zip, name} = get_location_info(user, city_names)
    name
  end
end
