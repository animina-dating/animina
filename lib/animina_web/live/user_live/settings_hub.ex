defmodule AniminaWeb.UserLive.SettingsHub do
  @moduledoc """
  Settings hub LiveView showing all settings categories.

  Features:
  - Profile summary with real-time avatar updates
  - Navigation to all settings pages
  - Preview of current settings values
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.GeoData
  alias Animina.Photos
  alias Animina.Traits
  alias AniminaWeb.Languages

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <.header>
            {gettext("Settings")}
            <:subtitle>{gettext("Manage your account and profile")}</:subtitle>
          </.header>
        </div>

        <%!-- Profile Summary with real-time avatar --%>
        <div class="flex items-center gap-4 mb-8 p-4 rounded-lg bg-base-200/50">
          <%= if @avatar_photo do %>
            <.live_component
              module={AniminaWeb.LivePhotoComponent}
              id={"avatar-#{@avatar_photo.id}"}
              photo={@avatar_photo}
              owner?={true}
              variant={:thumbnail}
              class="flex-shrink-0 w-14 h-14 rounded-full object-cover"
            />
          <% else %>
            <div class="flex-shrink-0 w-14 h-14 rounded-full bg-primary text-primary-content flex items-center justify-center text-xl font-bold">
              {String.first(@user.display_name)}
            </div>
          <% end %>
          <div>
            <div class="font-semibold text-base-content">{@user.display_name}</div>
            <div class="text-sm text-base-content/60">{@user.email}</div>
          </div>
        </div>

        <%!-- Section: Profile & Matching --%>
        <.section_heading title={gettext("Profile & Matching")} />

        <div class="grid gap-3 mb-8">
          <.settings_card
            navigate={~p"/users/settings/avatar"}
            icon="hero-camera"
            title={gettext("Profile Photo")}
            preview={@avatar_preview}
          />
          <.settings_card
            navigate={~p"/users/settings/profile"}
            icon="hero-user-circle"
            title={gettext("Edit Profile")}
            preview={@profile_preview}
          />
          <.settings_card
            navigate={~p"/users/settings/locations"}
            icon="hero-map-pin"
            title={gettext("Locations")}
            preview={@location_preview}
          />
          <.settings_card
            navigate={~p"/users/settings/preferences"}
            icon="hero-heart"
            title={gettext("Partner Preferences")}
            preview={@preferences_preview}
          />
          <.settings_card
            navigate={~p"/users/settings/traits"}
            icon="hero-flag"
            title={gettext("My Flags")}
            preview={@flags_preview}
          />
        </div>

        <%!-- Section: App --%>
        <.section_heading title={gettext("App")} />

        <div class="grid gap-3 mb-8">
          <.settings_card
            navigate={~p"/users/settings/language"}
            icon="hero-globe-alt"
            title={gettext("Language")}
            preview={@language_preview}
          />
        </div>

        <%!-- Section: Account --%>
        <.section_heading title={gettext("Account")} />

        <div class="grid gap-3 mb-8">
          <.settings_card
            navigate={~p"/users/settings/account"}
            icon="hero-shield-check"
            title={gettext("Account Security")}
            preview={@user.email}
          />
          <.settings_card
            navigate={~p"/users/settings/passkeys"}
            icon="hero-finger-print"
            title={gettext("Passkeys")}
            preview={@passkeys_preview}
          />
          <.settings_card
            navigate={~p"/users/settings/delete-account"}
            icon="hero-trash"
            title={gettext("Delete Account")}
            preview={gettext("Permanently delete your account")}
            variant={:danger}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true

  defp section_heading(assigns) do
    ~H"""
    <h2 class="text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3">
      {@title}
    </h2>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :preview, :string, default: nil
  attr :variant, :atom, default: :default

  defp settings_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-4 p-4 rounded-lg border transition-colors",
        if(@variant == :danger,
          do: "border-base-300 hover:border-error/50",
          else: "border-base-300 hover:border-primary"
        )
      ]}
    >
      <span class={[
        "flex-shrink-0",
        if(@variant == :danger, do: "text-error", else: "text-base-content/60")
      ]}>
        <.icon name={@icon} class="h-6 w-6" />
      </span>
      <div class="flex-1 min-w-0">
        <div class={[
          "font-semibold text-sm",
          if(@variant == :danger, do: "text-error", else: "text-base-content")
        ]}>
          {@title}
        </div>
        <div :if={@preview} class="text-xs text-base-content/60 truncate mt-0.5">
          {@preview}
        </div>
      </div>
      <span class="flex-shrink-0 text-base-content/30">
        <.icon name="hero-chevron-right-mini" class="h-5 w-5" />
      </span>
    </.link>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    locations = Accounts.list_user_locations(user)
    city_names = GeoData.city_names_for_locations(locations)
    flag_counts = Traits.count_user_flags_by_color(user)
    current_locale = Gettext.get_locale(AniminaWeb.Gettext)
    avatar_photo = Photos.get_user_avatar_any_state(user.id)

    # Subscribe to photo updates for real-time avatar status
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, "photos:User:#{user.id}")
    end

    user_age = compute_user_age(user.birthday)
    partner_min_age = user_age - user.partner_minimum_age_offset
    partner_max_age = user_age + user.partner_maximum_age_offset

    socket =
      socket
      |> assign(:page_title, gettext("Settings"))
      |> assign(:user, user)
      |> assign(:avatar_photo, avatar_photo)
      |> assign(:avatar_preview, build_avatar_preview(user))
      |> assign(:profile_preview, build_profile_preview(user, user_age))
      |> assign(:location_preview, build_location_preview(city_names))
      |> assign(
        :preferences_preview,
        build_preferences_preview(user, partner_min_age, partner_max_age)
      )
      |> assign(:flags_preview, build_flags_preview(flag_counts))
      |> assign(:language_preview, Languages.display_name(current_locale))
      |> assign(:passkeys_preview, build_passkeys_preview(user))

    {:ok, socket}
  end

  defp build_avatar_preview(user) do
    case Photos.get_user_avatar_any_state(user.id) do
      nil -> gettext("No photo")
      %{state: "approved"} -> gettext("Photo uploaded")
      %{state: "error"} -> gettext("Upload failed")
      _ -> gettext("Processing")
    end
  end

  defp compute_user_age(birthday) do
    today = Date.utc_today()
    age = today.year - birthday.year

    if {today.month, today.day} < {birthday.month, birthday.day} do
      age - 1
    else
      age
    end
  end

  defp build_profile_preview(user, user_age) do
    parts =
      [
        user.display_name,
        gettext("%{age} years", age: user_age),
        if(user.height, do: "#{user.height} cm"),
        user.occupation
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, ", ")
  end

  defp build_location_preview(city_names) when city_names == %{} do
    gettext("No locations")
  end

  defp build_location_preview(city_names) do
    city_names
    |> Map.values()
    |> Enum.join(", ")
  end

  defp build_preferences_preview(user, min_age, max_age) do
    gender_part =
      Enum.map_join(user.preferred_partner_gender, ", ", &gender_label/1)

    parts =
      [
        if(gender_part != "", do: gender_part),
        gettext("%{min}–%{max} years", min: min_age, max: max_age),
        gettext("%{radius} km", radius: user.search_radius)
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, ", ")
  end

  defp build_flags_preview(flag_counts) when flag_counts == %{} do
    gettext("Not configured")
  end

  defp build_flags_preview(flag_counts) do
    parts =
      [
        if(flag_counts["white"], do: gettext("%{count} white", count: flag_counts["white"])),
        if(flag_counts["green"], do: gettext("%{count} green", count: flag_counts["green"])),
        if(flag_counts["red"], do: gettext("%{count} red", count: flag_counts["red"]))
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: gettext("Not configured"), else: Enum.join(parts, ", ")
  end

  defp gender_label("male"), do: gettext("Male")
  defp gender_label("female"), do: gettext("Female")
  defp gender_label("diverse"), do: gettext("Diverse")
  defp gender_label(_), do: nil

  defp build_passkeys_preview(user) do
    count = length(Accounts.list_user_passkeys(user))

    case count do
      0 -> gettext("No passkeys")
      1 -> gettext("1 passkey")
      n -> gettext("%{count} passkeys", count: n)
    end
  end

  # Handle photo state changes for real-time avatar updates
  @impl true
  def handle_info({event, photo}, socket)
      when event in [:photo_state_changed, :photo_approved] do
    avatar_photo = socket.assigns.avatar_photo

    if avatar_photo && photo.id == avatar_photo.id do
      {:noreply, assign(socket, :avatar_photo, photo)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
