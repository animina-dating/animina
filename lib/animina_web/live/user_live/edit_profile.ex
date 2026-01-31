defmodule AniminaWeb.UserLive.EditProfile do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @valid_languages [
    {"Deutsch", "de"},
    {"English", "en"},
    {"Türkçe", "tr"},
    {"Русский", "ru"},
    {"العربية", "ar"},
    {"Polski", "pl"},
    {"Français", "fr"},
    {"Español", "es"},
    {"Українська", "uk"}
  ]

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
            <li>{gettext("Edit Profile")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Edit Profile")}
            <:subtitle>{gettext("Update your profile information")}</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="profile_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:display_name]}
            type="text"
            label={gettext("Display Name")}
            required
          />

          <.input
            field={@form[:height]}
            type="number"
            label={gettext("Height (cm)")}
            min="80"
            max="225"
            required
          />

          <.input
            field={@form[:occupation]}
            type="text"
            label={gettext("Occupation")}
          />

          <.input
            field={@form[:language]}
            type="select"
            label={gettext("Language")}
            options={@language_options}
          />

          <.button variant="primary" phx-disable-with={gettext("Saving...")}>
            {gettext("Save Profile")}
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    changeset = Accounts.change_user_profile(user)

    socket =
      socket
      |> assign(:page_title, gettext("Edit Profile"))
      |> assign(:language_options, @valid_languages)
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_profile(user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Profile updated successfully."))
         |> push_navigate(to: ~p"/users/settings/profile")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end
end
