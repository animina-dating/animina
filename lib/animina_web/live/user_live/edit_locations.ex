defmodule AniminaWeb.UserLive.EditLocations do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.GeoData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.profile_header
          title={gettext("Locations")}
          subtitle={gettext("Manage your locations")}
        />

        <%= if @locations == [] do %>
          <p class="text-sm text-base-content/70 mb-4">{gettext("No locations added yet.")}</p>
        <% else %>
          <div class="space-y-2 mb-4">
            <%= for location <- @locations do %>
              <%= if @editing_id == location.id do %>
                <div class="p-3 rounded-lg border border-primary">
                  <.form
                    for={@edit_form}
                    id="edit_location_form"
                    phx-submit="save_location"
                    phx-change="validate_edit"
                  >
                    <input type="hidden" name="location_id" value={location.id} />
                    <div class="grid grid-cols-2 gap-4">
                      <.input
                        field={@edit_form[:country_id]}
                        type="select"
                        label={gettext("Country")}
                        options={@country_options}
                      />
                      <.input
                        field={@edit_form[:zip_code]}
                        type="text"
                        label={gettext("Zip Code")}
                        placeholder="12345"
                      />
                    </div>
                    <div class="flex gap-2 mt-2">
                      <.button variant="primary" phx-disable-with={gettext("Saving...")}>
                        {gettext("Save")}
                      </.button>
                      <button
                        type="button"
                        phx-click="cancel_edit"
                        class="btn btn-outline"
                      >
                        {gettext("Cancel")}
                      </button>
                    </div>
                  </.form>
                </div>
              <% else %>
                <div class="flex items-center justify-between p-3 rounded-lg border border-base-300">
                  <span class="text-sm text-base-content whitespace-nowrap">
                    {location.zip_code}
                    <%= if @city_names[location.zip_code] do %>
                      ({@city_names[location.zip_code]})
                    <% end %>
                  </span>
                  <div class="flex gap-1">
                    <button
                      type="button"
                      phx-click="edit_location"
                      phx-value-id={location.id}
                      class="btn btn-outline btn-xs gap-1"
                      aria-label={gettext("Edit")}
                    >
                      <.icon name="hero-pencil-square-mini" class="h-3.5 w-3.5" />
                      {gettext("Edit")}
                    </button>
                    <button
                      :if={length(@locations) > 1}
                      type="button"
                      phx-click="remove_location"
                      phx-value-id={location.id}
                      class="btn btn-outline btn-error btn-xs gap-1"
                      aria-label={gettext("Remove")}
                    >
                      <.icon name="hero-trash-mini" class="h-3.5 w-3.5" />
                      {gettext("Remove")}
                    </button>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>

        <%= if length(@locations) < Accounts.max_locations() && @editing_id == nil do %>
          <.form
            for={@location_form}
            id="location_form"
            phx-submit="add_location"
            phx-change="validate_add"
          >
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

    city_names = GeoData.city_names_for_locations(locations)

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
      |> assign(:page_title, gettext("My Locations"))
      |> assign(:country_options, country_options)
      |> assign(:default_country_id, default_country_id)
      |> assign(:locations, locations)
      |> assign(:city_names, city_names)
      |> assign(:location_form, to_form(location_changeset, as: "location"))
      |> assign(:editing_id, nil)
      |> assign(:edit_form, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_add", %{"location" => params}, socket) do
    user = socket.assigns.current_scope.user

    changeset =
      %Accounts.UserLocation{}
      |> Accounts.UserLocation.changeset(
        params
        |> Map.put("user_id", user.id)
        |> Map.put("position", 1)
      )
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, location_form: to_form(changeset, as: "location"))}
  end

  def handle_event("add_location", %{"location" => location_params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.add_user_location(
           user,
           %{
             country_id: location_params["country_id"],
             zip_code: location_params["zip_code"]
           },
           originator: user
         ) do
      {:ok, _location} ->
        Animina.Analytics.maybe_log_profile_completed(user)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Location added."))
         |> push_navigate(to: ~p"/my/settings/profile/locations")}

      {:error, :max_locations_reached} ->
        {:noreply, put_flash(socket, :error, gettext("You can have at most 4 locations."))}

      {:error, changeset} ->
        {:noreply,
         assign(socket, location_form: to_form(changeset, as: "location", action: :insert))}
    end
  end

  def handle_event("edit_location", %{"id" => location_id}, socket) do
    location = Enum.find(socket.assigns.locations, &(&1.id == location_id))

    if location do
      changeset =
        Accounts.UserLocation.changeset(location, %{})

      {:noreply,
       socket
       |> assign(:editing_id, location_id)
       |> assign(:edit_form, to_form(changeset, as: "location"))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate_edit", %{"location" => params}, socket) do
    location = Enum.find(socket.assigns.locations, &(&1.id == socket.assigns.editing_id))

    changeset =
      (location || %Accounts.UserLocation{})
      |> Accounts.UserLocation.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, edit_form: to_form(changeset, as: "location"))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_id, nil)
     |> assign(:edit_form, nil)}
  end

  def handle_event("save_location", %{"location_id" => location_id, "location" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_location(
           user,
           location_id,
           %{
             country_id: params["country_id"],
             zip_code: params["zip_code"]
           },
           originator: user
         ) do
      {:ok, _location} ->
        Animina.Analytics.maybe_log_profile_completed(user)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Location updated."))
         |> push_navigate(to: ~p"/my/settings/profile/locations")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, gettext("Location not found."))}

      {:error, changeset} ->
        {:noreply, assign(socket, edit_form: to_form(changeset, as: "location", action: :update))}
    end
  end

  def handle_event("remove_location", %{"id" => location_id}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.remove_user_location(user, location_id, originator: user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Location removed."))
         |> push_navigate(to: ~p"/my/settings/profile/locations")}

      {:error, :last_location} ->
        {:noreply, put_flash(socket, :error, gettext("You must have at least one location."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not remove location."))}
    end
  end
end
