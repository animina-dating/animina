defmodule AniminaWeb.UserLive.ProfileMoodboardLive do
  @moduledoc """
  LiveView for displaying a user's moodboard.

  Features:
  - Editorial magazine-style Pinterest masonry layout
  - Three item types: photo cards, quote cards, combined cards
  - Soft shadows and premium visual polish
  - Owner view shows hidden items with status
  - Column preferences persisted per device type
  - Real-time updates via PubSub subscriptions
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.Scope
  alias Animina.FeatureFlags
  alias Animina.GeoData
  alias Animina.Moodboard
  alias Animina.Traits

  import AniminaWeb.MoodboardComponents, only: [distribute_to_columns: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="moodboard-container" class="mx-auto max-w-6xl px-4 py-8" phx-hook="DeviceType">
        <!-- Header -->
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold">{@profile_user.display_name}</h1>
            <p class="text-base-content/60">
              {gettext("%{age} years", age: @age)}
              <%= if @city do %>
                · {@zip_code} {@city.name}
              <% end %>
            </p>
            <div
              :if={
                (@flag_counts["green"] && @flag_counts["green"] > 0) ||
                  (@flag_counts["red"] && @flag_counts["red"] > 0)
              }
              class="flex gap-3 mt-2 text-sm"
            >
              <span class="text-base-content/60">{gettext("Partner flags:")}</span>
              <span
                :if={@flag_counts["green"] && @flag_counts["green"] > 0}
                class="flex items-center gap-1"
              >
                <span class="w-3 h-3 rounded-full bg-green-500"></span>
                {@flag_counts["green"]}
              </span>
              <span
                :if={@flag_counts["red"] && @flag_counts["red"] > 0}
                class="flex items-center gap-1"
              >
                <span class="w-3 h-3 rounded-full bg-red-500"></span>
                {@flag_counts["red"]}
              </span>
            </div>
          </div>

          <.link
            :if={@owner?}
            navigate={~p"/users/settings/moodboard"}
            class="btn btn-primary"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 mr-2"
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
            {gettext("Edit Moodboard")}
          </.link>
        </div>
        
    <!-- White flags display -->
        <div :if={length(@white_flags) > 0 || @private_white_flags_count > 0} class="mb-8">
          <div class="flex flex-wrap gap-3">
            <%= for {category_name, flags} <- group_flags_by_category(@white_flags) do %>
              <div class="inline-flex items-center gap-2 bg-base-100 rounded-2xl px-4 py-2.5 shadow-[0_2px_8px_-2px_rgba(0,0,0,0.08)] border border-base-200/80">
                <span class="text-xs font-medium text-base-content/40 uppercase tracking-wide shrink-0">
                  {AniminaWeb.TraitTranslations.translate(category_name)}
                </span>
                <div class="flex flex-wrap items-center gap-2">
                  <%= for user_flag <- flags do %>
                    <span class="inline-flex items-center gap-1 text-sm bg-base-200/50 rounded-lg px-2 py-0.5">
                      <span>{user_flag.flag.emoji}</span>
                      <span class="text-base-content/80">
                        {AniminaWeb.TraitTranslations.translate(user_flag.flag.name)}
                      </span>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
            <div
              :if={@private_white_flags_count > 0}
              class="inline-flex items-center gap-1.5 bg-base-200/30 rounded-2xl px-4 py-2.5 text-base-content/40 text-sm border border-dashed border-base-300"
              title={gettext("Private flags not shown on profile")}
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
                  d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
                />
              </svg>
              <span>+{@private_white_flags_count} {gettext("private")}</span>
            </div>
          </div>
        </div>
        
    <!-- Empty state -->
        <div :if={Enum.empty?(@items)} class="text-center py-16">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-16 w-16 mx-auto text-base-content/30 mb-4"
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
          <h2 class="text-xl font-semibold text-base-content/60">
            {gettext("No moodboard items yet")}
          </h2>
          <p :if={@owner?} class="text-base-content/50 mt-2">
            {gettext("Add photos and text to your moodboard to share with others.")}
          </p>
        </div>
        
    <!-- Editorial moodboard with real-time updates -->
        <div :if={!Enum.empty?(@items)}>
          <!-- Column toggle -->
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
          
    <!-- Moodboard grid using Flexbox columns -->
          <div class={[
            "flex gap-4 md:gap-5 lg:gap-6 pt-6",
            if(@columns == 1, do: "flex-col", else: "flex-row")
          ]}>
            <%= for {column_items, col_idx} <- distribute_to_columns(@items, column_count(@columns)) do %>
              <div class="flex-1 flex flex-col gap-4 md:gap-5 lg:gap-6">
                <%= for item <- column_items do %>
                  <div>
                    <.live_component
                      module={AniminaWeb.LiveMoodboardItemComponent}
                      id={"moodboard-item-#{item.id}"}
                      item={item}
                      owner?={@owner?}
                    />
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Return the column count (validated to 1, 2, or 3)
  defp column_count(columns) when columns in [1, 2, 3], do: columns
  defp column_count(_), do: 2

  # Group white flags by their category name, preserving order
  defp group_flags_by_category(white_flags) do
    white_flags
    |> Enum.group_by(& &1.flag.category.name)
    |> Enum.sort_by(fn {_name, flags} ->
      # Sort by the first flag's category position (flags are already ordered by category)
      hd(flags).flag.category.position
    end)
  end

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    current_scope = socket.assigns.current_scope
    current_user = current_scope && current_scope.user
    profile_user = Accounts.get_user(user_id)

    case check_access(current_user, profile_user, current_scope) do
      {:ok, owner?} ->
        {:ok, mount_moodboard(socket, profile_user, current_user, owner?)}

      :denied ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This page doesn't exist or you don't have access."))
         |> redirect(to: ~p"/")}
    end
  end

  defp check_access(current_user, profile_user, current_scope) do
    owner? = current_user && profile_user && current_user.id == profile_user.id

    admin_viewing? =
      profile_user &&
        !owner? &&
        Scope.admin?(current_scope) &&
        FeatureFlags.admin_can_view_moodboards?()

    cond do
      owner? -> {:ok, true}
      admin_viewing? -> {:ok, false}
      true -> :denied
    end
  end

  defp mount_moodboard(socket, profile_user, current_user, owner?) do
    items = Moodboard.list_moodboard_with_hidden(profile_user.id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, "moodboard:#{profile_user.id}")
    end

    # Compute age
    age = Accounts.compute_age(profile_user.birthday)

    # Get primary location (position 1) with city name
    locations = Accounts.list_user_locations(profile_user)
    primary_location = Enum.find(locations, &(&1.position == 1))

    {city, zip_code} =
      if primary_location do
        {GeoData.get_city_by_zip_code(primary_location.zip_code), primary_location.zip_code}
      else
        {nil, nil}
      end

    # Get flag counts (only includes white flags from published categories)
    flag_counts = Traits.count_published_user_flags_by_color(profile_user)

    # Get published white flags for display
    white_flags = Traits.list_published_white_flags(profile_user)
    private_white_flags_count = Traits.count_private_white_flags(profile_user)

    assign(socket,
      page_title: profile_user.display_name,
      profile_user: profile_user,
      owner?: owner?,
      items: items,
      current_user_id: current_user.id,
      device_type: "desktop",
      columns: 3,
      age: age,
      city: city,
      zip_code: zip_code,
      flag_counts: flag_counts,
      white_flags: white_flags,
      private_white_flags_count: private_white_flags_count
    )
  end

  @impl true
  def handle_event("device_type_detected", %{"device_type" => device_type}, socket) do
    # Load column preference for this device type from user's preferences
    columns = get_columns_for_device(socket, device_type)
    {:noreply, assign(socket, device_type: device_type, columns: columns)}
  end

  @impl true
  def handle_event("change_columns", %{"columns" => columns_str}, socket) do
    columns = String.to_integer(columns_str)

    # Save preference if owner is logged in
    if socket.assigns.owner? do
      user = socket.assigns.current_scope.user
      device_type = socket.assigns.device_type
      Accounts.update_moodboard_columns(user, device_type, columns)
    end

    {:noreply, assign(socket, :columns, columns)}
  end

  defp get_columns_for_device(socket, device_type) do
    if socket.assigns.owner? do
      get_user_columns(socket.assigns.current_scope.user, device_type)
    else
      get_default_columns(device_type)
    end
  end

  defp get_user_columns(user, device_type) do
    case device_type do
      "mobile" -> user.moodboard_columns_mobile || 2
      "tablet" -> user.moodboard_columns_tablet || 2
      "desktop" -> user.moodboard_columns_desktop || 3
      _ -> 2
    end
  end

  defp get_default_columns(device_type) do
    case device_type do
      "mobile" -> 2
      "tablet" -> 2
      "desktop" -> 3
      _ -> 2
    end
  end

  # Handle moodboard PubSub messages - all trigger a reload
  @impl true
  def handle_info({event, _payload}, socket)
      when event in [
             :moodboard_item_created,
             :moodboard_item_deleted,
             :moodboard_item_updated,
             :moodboard_positions_updated,
             :story_updated
           ] do
    {:noreply, reload_items(socket)}
  end

  # Handle white flag updates
  @impl true
  def handle_info({:white_flags_updated, _payload}, socket) do
    {:noreply, reload_white_flags(socket)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp reload_items(socket) do
    items = Moodboard.list_moodboard_with_hidden(socket.assigns.profile_user.id)
    assign(socket, :items, items)
  end

  defp reload_white_flags(socket) do
    profile_user = socket.assigns.profile_user
    flag_counts = Traits.count_published_user_flags_by_color(profile_user)
    white_flags = Traits.list_published_white_flags(profile_user)
    private_white_flags_count = Traits.count_private_white_flags(profile_user)

    assign(socket,
      flag_counts: flag_counts,
      white_flags: white_flags,
      private_white_flags_count: private_white_flags_count
    )
  end
end
