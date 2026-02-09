defmodule AniminaWeb.UserLive.EditProfile do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.profile_header
          title={gettext("Edit Profile")}
          subtitle={gettext("Update your profile information")}
        />

        <.form for={@form} id="profile_form" phx-submit="save" phx-change="validate">
          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:first_name]}
              type="text"
              label={gettext("First name")}
              required
            />
            <.input
              field={@form[:last_name]}
              type="text"
              label={gettext("Last name")}
              required
            />
          </div>

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

          <div class="mb-4">
            <label class="label">
              <span class="label-text">{gettext("Birthday")}</span>
            </label>
            <input
              type="text"
              value={Date.to_iso8601(@birthday)}
              disabled
              class="input input-bordered w-full opacity-60"
            />
            <p class="text-xs text-base-content/60 mt-1">
              {gettext("This field cannot be changed.")}
            </p>
          </div>

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
      |> assign(:birthday, user.birthday)
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

    case Accounts.update_user_profile(user, user_params, originator: user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Profile updated successfully."))
         |> push_navigate(to: ~p"/settings/profile")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end
end
