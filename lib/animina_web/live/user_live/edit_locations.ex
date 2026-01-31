defmodule AniminaWeb.UserLive.EditLocations do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.GeoData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/users/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>{gettext("Locations")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Locations")}
            <:subtitle>{gettext("Manage your locations")}</:subtitle>
          </.header>
        </div>

        <%= if @locations == [] do %>
          <p class="text-sm text-base-content/70 mb-4">{gettext("No locations added yet.")}</p>
        <% else %>
          <div class="space-y-2 mb-4">
            <div
              :for={location <- @locations}
              class="flex items-center justify-between p-3 rounded-lg border border-base-300"
            >
              <span class="text-sm text-base-content">
                {location.zip_code}
                <%= if @city_names[location.zip_code] do %>
                  ({@city_names[location.zip_code]})
                <% end %>
              </span>
              <button
                :if={length(@locations) > 1}
                type="button"
                phx-click="remove_location"
                phx-value-id={location.id}
                class="btn btn-ghost btn-xs text-error"
              >
                {gettext("Remove")}
              </button>
            </div>
          </div>
        <% end %>

        <%= if length(@locations) < 4 do %>
          <.form for={@location_form} id="location_form" phx-submit="add_location">
            <div class="grid grid-cols-2 gap-4">
              <.input
                field={@location_form[:country_id]}
                type="select"
                label={gettext("Country")}
                options={@country_options}
              />
              <.input
                field={@location_form[:zip_code]}
                type="text"
                label={gettext("Zip Code")}
                placeholder="12345"
              />
            </div>
            <.button variant="primary" phx-disable-with={gettext("Adding...")}>
              {gettext("Add Location")}
            </.button>
          </.form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    locations = Accounts.list_user_locations(user)
    countries = GeoData.list_countries()
    country_options = Enum.map(countries, &{&1.name, &1.id})

    city_names = build_city_names(locations)

    default_country_id =
      case countries do
        [] -> nil
        _ -> (Enum.find(countries, &(&1.code == "DE")) || List.first(countries)).id
      end

    location_changeset =
      Accounts.UserLocation.changeset(%Accounts.UserLocation{}, %{
        country_id: default_country_id
      })

    socket =
      socket
      |> assign(:page_title, gettext("Locations"))
      |> assign(:country_options, country_options)
      |> assign(:locations, locations)
      |> assign(:city_names, city_names)
      |> assign(:location_form, to_form(location_changeset, as: "location"))

    {:ok, socket}
  end

  @impl true
  def handle_event("add_location", %{"location" => location_params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.add_user_location(user, %{
           country_id: location_params["country_id"],
           zip_code: location_params["zip_code"]
         }) do
      {:ok, _location} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Location added."))
         |> push_navigate(to: ~p"/users/settings/locations")}

      {:error, :max_locations_reached} ->
        {:noreply, put_flash(socket, :error, gettext("You can have at most 4 locations."))}

      {:error, changeset} ->
        {:noreply,
         assign(socket, location_form: to_form(changeset, as: "location", action: :insert))}
    end
  end

  def handle_event("remove_location", %{"id" => location_id}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.remove_user_location(user, location_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Location removed."))
         |> push_navigate(to: ~p"/users/settings/locations")}

      {:error, :last_location} ->
        {:noreply, put_flash(socket, :error, gettext("You must have at least one location."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not remove location."))}
    end
  end

  defp build_city_names(locations) do
    Enum.reduce(locations, %{}, fn loc, acc ->
      case GeoData.get_city_by_zip_code(loc.zip_code) do
        nil -> acc
        city -> Map.put(acc, loc.zip_code, city.name)
      end
    end)
  end
end
