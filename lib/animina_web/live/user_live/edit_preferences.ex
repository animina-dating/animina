defmodule AniminaWeb.UserLive.EditPreferences do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @valid_genders [
    {"Male", "male"},
    {"Female", "female"},
    {"Diverse", "diverse"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.profile_header
          title={gettext("Partner Preferences")}
          subtitle={gettext("Update your partner preferences")}
        />

        <.form
          for={@preferences_form}
          id="preferences_form"
          phx-submit="save_preferences"
          phx-change="validate_preferences"
        >
          <fieldset>
            <legend class="text-sm font-semibold text-base-content mb-2">
              {gettext("Preferred Partner Gender")}
            </legend>
            <div class="flex flex-wrap gap-4">
              <label :for={{label, value} <- @gender_options} class="flex items-center gap-2">
                <input
                  type="checkbox"
                  name="user[preferred_partner_gender][]"
                  value={value}
                  checked={value in (@preferences_form[:preferred_partner_gender].value || [])}
                  class="checkbox checkbox-primary"
                />
                <span>{label}</span>
              </label>
            </div>
            <%!-- Hidden field to ensure empty array is sent when nothing checked --%>
            <input type="hidden" name="user[preferred_partner_gender][]" value="" />
          </fieldset>

          <div class="grid grid-cols-2 gap-4 mt-4">
            <.input
              field={@preferences_form[:partner_minimum_age]}
              type="number"
              label={gettext("Minimum Age")}
              min="18"
            />
            <.input
              field={@preferences_form[:partner_maximum_age]}
              type="number"
              label={gettext("Maximum Age")}
              min="18"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@preferences_form[:partner_height_min]}
              type="number"
              label={gettext("Min Height (cm)")}
              min="80"
              max="225"
            />
            <.input
              field={@preferences_form[:partner_height_max]}
              type="number"
              label={gettext("Max Height (cm)")}
              min="80"
              max="225"
            />
          </div>

          <.input
            field={@preferences_form[:search_radius]}
            type="number"
            label={gettext("Search Radius (km)")}
            min="1"
          />

          <.button variant="primary" phx-disable-with={gettext("Saving...")}>
            {gettext("Save Preferences")}
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Compute virtual age fields from stored offsets
    user_age = compute_user_age(user.birthday)

    preferences_attrs = %{
      "partner_minimum_age" => user_age - user.partner_minimum_age_offset,
      "partner_maximum_age" => user_age + user.partner_maximum_age_offset
    }

    changeset = Accounts.change_user_preferences(user, preferences_attrs)

    socket =
      socket
      |> assign(:page_title, gettext("Partner Preferences"))
      |> assign(:gender_options, @valid_genders)
      |> assign(:preferences_form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_preferences", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    form =
      user
      |> Accounts.change_user_preferences(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, preferences_form: form)}
  end

  def handle_event("save_preferences", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_preferences(user, user_params, originator: user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Preferences updated successfully."))
         |> push_navigate(to: ~p"/settings/profile/preferences")}

      {:error, changeset} ->
        {:noreply, assign(socket, preferences_form: to_form(changeset, action: :insert))}
    end
  end

  defp compute_user_age(birthday) do
    today = Date.utc_today()
    age = today.year - birthday.year

    if {today.month, today.day} < {birthday.month, birthday.day},
      do: age - 1,
      else: age
  end
end
