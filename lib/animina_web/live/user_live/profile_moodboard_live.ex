defmodule AniminaWeb.UserLive.ProfileMoodboardLive do
  @moduledoc """
  LiveView for displaying a user's moodboard.

  Features:
  - Editorial magazine-style Pinterest masonry layout
  - Three item types: photo cards, quote cards, combined cards
  - Soft shadows and premium visual polish
  - Owner view shows hidden items with status
  - Column preferences persisted per device type
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Moodboard

  import AniminaWeb.MoodboardComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="moodboard-container" class="mx-auto max-w-6xl px-4 py-8" phx-hook="DeviceType">
        <!-- Header -->
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold">{@profile_user.display_name}</h1>
            <p class="text-base-content/60">{gettext("Moodboard")}</p>
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
        
    <!-- Editorial moodboard -->
        <.editorial_moodboard
          :if={!Enum.empty?(@items)}
          items={@items}
          current_user_id={@current_user_id}
          owner?={@owner?}
          columns={@columns}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    case Accounts.get_user(user_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("User not found"))
         |> redirect(to: ~p"/")}

      profile_user ->
        current_user = socket.assigns.current_scope && socket.assigns.current_scope.user
        owner? = current_user && current_user.id == profile_user.id

        items =
          if owner? do
            Moodboard.list_moodboard_with_hidden(profile_user.id)
          else
            Moodboard.list_moodboard(profile_user.id)
          end

        {:ok,
         assign(socket,
           page_title: "#{profile_user.display_name} - #{gettext("Moodboard")}",
           profile_user: profile_user,
           owner?: owner?,
           items: items,
           current_user_id: current_user && current_user.id,
           device_type: "desktop",
           columns: 3
         )}
    end
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
end
