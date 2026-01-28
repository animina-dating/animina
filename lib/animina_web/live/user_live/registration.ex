defmodule AniminaWeb.UserLive.Registration do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.GeoData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              Konto erstellen
            </h1>
            <p class="mt-2 text-base text-base-content/70">
              Bereits registriert?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-primary hover:underline">
                Jetzt anmelden
              </.link>
            </p>
          </div>

          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-8"
          >
            <%!-- Section 1: Zugangsdaten --%>
            <div id="section-1">
              <fieldset>
                <legend class="text-xl font-medium text-base-content mb-4">
                  1. Zugangsdaten
                </legend>
                <div class="space-y-4">
                  <.input
                    field={@form[:email]}
                    type="email"
                    label="E-Mail-Adresse"
                    autocomplete="username"
                    required
                    phx-mounted={JS.focus()}
                  />
                  <.input
                    field={@form[:password]}
                    type="password"
                    label="Passwort (mind. 12 Zeichen)"
                    autocomplete="new-password"
                    required
                  />
                  <.input
                    field={@form[:mobile_phone]}
                    type="tel"
                    label="Handynummer (z.B. +491514567890)"
                    required
                    phx-blur="normalize_phone"
                  />
                </div>
              </fieldset>
            </div>

            <%!-- Section 2: Wohnort --%>
            <div id="section-2" class={if(@unlocked_section < 2, do: "section-locked opacity-40 pointer-events-none select-none")}>
              <fieldset>
                <legend class="text-xl font-medium text-base-content mb-4">
                  2. Wohnort
                  <span :if={@unlocked_section < 2} class="text-sm font-normal text-base-content/50 ml-2">
                    (bitte zuerst Zugangsdaten ausfüllen)
                  </span>
                </legend>
                <div class="space-y-4">
                  <.input
                    field={@form[:country_id]}
                    type="select"
                    label="Land"
                    options={@country_options}
                    required
                  />
                  <.input
                    field={@form[:zip_code]}
                    type="text"
                    label="Postleitzahl (5 Ziffern)"
                    required
                  />
                  <p :if={@city_name} class="text-sm text-base-content/70 -mt-2">
                    {@city_name}
                  </p>
                </div>
              </fieldset>
            </div>

            <%!-- Section 3: Profil --%>
            <div id="section-3" class={if(@unlocked_section < 3, do: "section-locked opacity-40 pointer-events-none select-none")}>
              <fieldset>
                <legend class="text-xl font-medium text-base-content mb-4">
                  3. Profil
                  <span :if={@unlocked_section < 3} class="text-sm font-normal text-base-content/50 ml-2">
                    (bitte zuerst Wohnort ausfüllen)
                  </span>
                </legend>
                <div class="space-y-4">
                  <.input
                    field={@form[:display_name]}
                    type="text"
                    label="Anzeigename (2-50 Zeichen)"
                    required
                  />
                  <.input
                    field={@form[:birthday]}
                    type="date"
                    label="Geburtstag (mind. 18 Jahre)"
                    required
                  />
                  <.input
                    field={@form[:gender]}
                    type="radio"
                    label="Geschlecht"
                    options={[
                      {"Männlich", "male"},
                      {"Weiblich", "female"},
                      {"Divers", "diverse"}
                    ]}
                    required
                  />
                  <.input
                    field={@form[:height]}
                    type="number"
                    label="Größe in cm (80-225)"
                    min="80"
                    max="225"
                    required
                  />
                </div>

                <div class="space-y-4">
                  <.input
                    field={@form[:occupation]}
                    type="text"
                    label="Beruf"
                  />
                  <.input
                    field={@form[:language]}
                    type="select"
                    label="Sprache"
                    options={[{"Deutsch", "de"}, {"English", "en"}]}
                  />
                </div>
              </fieldset>
            </div>

            <%!-- Section 4: Partnerwünsche --%>
            <div id="section-4" class={if(@unlocked_section < 4, do: "section-locked opacity-40 pointer-events-none select-none")}>
              <fieldset>
                <legend class="text-xl font-medium text-base-content mb-4">
                  4. Partnerwünsche
                  <span :if={@unlocked_section < 4} class="text-sm font-normal text-base-content/50 ml-2">
                    (bitte zuerst Profil ausfüllen)
                  </span>
                </legend>
                <div class="space-y-4">
                  <div class="fieldset mb-2">
                    <span class="label mb-1">Bevorzugtes Geschlecht</span>
                    <input type="hidden" name="user[preferred_partner_gender][]" value="" />
                    <div class="flex gap-4">
                      <label
                        :for={
                          {label, value} <- [
                            {"Männlich", "male"},
                            {"Weiblich", "female"},
                            {"Divers", "diverse"}
                          ]
                        }
                        class="label cursor-pointer gap-2"
                      >
                        <input
                          type="checkbox"
                          name="user[preferred_partner_gender][]"
                          value={value}
                          checked={value in (@form[:preferred_partner_gender].value || [])}
                          class="checkbox checkbox-sm"
                        />
                        {label}
                      </label>
                    </div>
                  </div>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <.input
                      field={@form[:partner_minimum_age_offset]}
                      type="number"
                      label="Max. Jahre jünger"
                      min="0"
                    />
                    <.input
                      field={@form[:partner_maximum_age_offset]}
                      type="number"
                      label="Max. Jahre älter"
                      min="0"
                    />
                  </div>
                  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <.input
                      field={@form[:partner_height_min]}
                      type="number"
                      label="Mindestgröße (cm)"
                      min="80"
                      max="225"
                    />
                    <.input
                      field={@form[:partner_height_max]}
                      type="number"
                      label="Maximalgröße (cm)"
                      min="80"
                      max="225"
                    />
                  </div>
                  <.input
                    field={@form[:search_radius]}
                    type="number"
                    label="Suchradius (km)"
                    min="1"
                  />
                </div>
              </fieldset>
            </div>

            <%!-- Section 5: AGB --%>
            <div id="section-5" class={if(@unlocked_section < 5, do: "section-locked opacity-40 pointer-events-none select-none")}>
              <fieldset>
                <legend class="text-xl font-medium text-base-content mb-4">
                  5. Rechtliches
                  <span :if={@unlocked_section < 5} class="text-sm font-normal text-base-content/50 ml-2">
                    (bitte zuerst Profil ausfüllen)
                  </span>
                </legend>
                <.input
                  field={@form[:terms_accepted]}
                  type="checkbox"
                  label="Ich akzeptiere die Allgemeinen Geschäftsbedingungen und die Datenschutzerklärung."
                  required
                />
              </fieldset>
            </div>

            <.button
              phx-disable-with="Konto wird erstellt..."
              class="btn btn-primary w-full"
              disabled={@unlocked_section < 5}
            >
              Konto erstellen
            </.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: AniminaWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    countries = GeoData.list_countries()
    germany = Enum.find(countries, fn c -> c.code == "DE" end)

    country_options = Enum.map(countries, fn c -> {c.name, c.id} end)

    min_birthday = Date.utc_today() |> Date.shift(year: -18)

    initial_attrs =
      if germany do
        %{
          "country_id" => germany.id,
          "birthday" => min_birthday,
          "gender" => "male",
          "height" => 170,
          "preferred_partner_gender" => ["female"]
        }
      else
        %{"birthday" => min_birthday, "gender" => "male", "height" => 170, "preferred_partner_gender" => ["female"]}
      end

    changeset = Accounts.change_user_registration(%User{}, initial_attrs)

    unlocked_section = compute_unlocked_section(initial_attrs)

    socket =
      socket
      |> assign(country_options: country_options)
      |> assign(preferences_auto_filled: false)
      |> assign(unlocked_section: unlocked_section)
      |> assign(last_params: initial_attrs)
      |> assign(city_name: nil)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Eine E-Mail wurde an #{user.email} gesendet. Bitte bestätige dein Konto."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(unlocked_section: compute_unlocked_section(user_params))
         |> assign_form(changeset)}
    end
  end

  def handle_event("normalize_phone", %{"value" => phone}, socket) do
    case ExPhoneNumber.parse(phone, "DE") do
      {:ok, parsed} ->
        formatted = ExPhoneNumber.format(parsed, :e164)
        params = Map.put(socket.assigns.last_params, "mobile_phone", formatted)

        changeset =
          Accounts.change_user_registration(%User{}, params)
          |> Map.put(:action, :validate)

        {:noreply,
         socket
         |> assign(last_params: params)
         |> assign(unlocked_section: compute_unlocked_section(params))
         |> assign_form(changeset)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    user_params = normalize_mobile_phone(user_params)
    {user_params, socket} = maybe_auto_fill_preferences(user_params, socket)
    unlocked_section = compute_unlocked_section(user_params)
    city_name = lookup_city_name(user_params["zip_code"])

    changeset =
      Accounts.change_user_registration(%User{}, user_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(unlocked_section: unlocked_section)
     |> assign(last_params: user_params)
     |> assign(city_name: city_name)
     |> assign_form(changeset)}
  end

  defp maybe_auto_fill_preferences(params, socket) do
    if socket.assigns.preferences_auto_filled do
      {params, socket}
    else
      gender = params["gender"]
      height = parse_int(params["height"])

      if gender in ["male", "female", "diverse"] and height do
        params =
          params
          |> maybe_set_list("preferred_partner_gender", compute_preferred_gender(gender))
          |> maybe_set("partner_minimum_age_offset", compute_min_age_offset(gender))
          |> maybe_set("partner_maximum_age_offset", compute_max_age_offset(gender))
          |> maybe_set("partner_height_min", compute_height_min(gender, height))
          |> maybe_set("partner_height_max", compute_height_max(gender, height))

        {params, assign(socket, preferences_auto_filled: true)}
      else
        {params, socket}
      end
    end
  end

  defp maybe_set(params, key, value) do
    if is_nil(params[key]) or params[key] == "" do
      Map.put(params, key, to_string(value))
    else
      params
    end
  end

  defp maybe_set_list(params, key, value) do
    current = params[key]

    if is_nil(current) or current == "" or current == [""] or current == [] do
      Map.put(params, key, value)
    else
      params
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val

  defp compute_preferred_gender("male"), do: ["female"]
  defp compute_preferred_gender("female"), do: ["male"]
  defp compute_preferred_gender("diverse"), do: ["diverse"]

  defp compute_min_age_offset("male"), do: 6
  defp compute_min_age_offset("female"), do: 2
  defp compute_min_age_offset("diverse"), do: 6

  defp compute_max_age_offset("male"), do: 2
  defp compute_max_age_offset("female"), do: 6
  defp compute_max_age_offset("diverse"), do: 6

  defp compute_height_min("male", _height), do: 80
  defp compute_height_min("female", height), do: max(80, height - 5)
  defp compute_height_min("diverse", height), do: max(80, height - 15)

  defp compute_height_max("male", height), do: min(225, height + 5)
  defp compute_height_max("female", _height), do: 225
  defp compute_height_max("diverse", _height), do: 225

  defp compute_unlocked_section(params) do
    cond do
      not filled?(params, ~w(email password mobile_phone)) -> 1
      not filled?(params, ~w(country_id zip_code)) -> 2
      not filled?(params, ~w(display_name birthday gender height)) -> 3
      true -> 5
    end
  end

  defp filled?(params, keys) do
    Enum.all?(keys, fn key ->
      string_val = params[key]
      atom_val = params[String.to_atom(key)]
      val = string_val || atom_val
      val != nil and to_string(val) != ""
    end)
  end

  defp lookup_city_name(zip_code) when is_binary(zip_code) and byte_size(zip_code) == 5 do
    case GeoData.get_city_by_zip_code(zip_code) do
      %{name: name} -> name
      nil -> nil
    end
  end

  defp lookup_city_name(_), do: nil

  defp normalize_mobile_phone(%{"mobile_phone" => phone} = params) when is_binary(phone) do
    case ExPhoneNumber.parse(phone, "DE") do
      {:ok, parsed} ->
        Map.put(params, "mobile_phone", ExPhoneNumber.format(parsed, :e164))

      _ ->
        params
    end
  end

  defp normalize_mobile_phone(params), do: params

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
