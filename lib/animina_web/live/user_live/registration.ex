defmodule AniminaWeb.UserLive.Registration do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.GeoData

  @step_titles %{1 => "Zugang", 2 => "Profil", 3 => "Wohnort", 4 => "Partner"}
  @step_required_fields %{
    1 => ~w(email password mobile_phone birthday),
    2 => ~w(display_name gender height),
    3 => ~w(country_id zip_code),
    4 => []
  }

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

          <.step_indicator current_step={@current_step} />

          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-6"
          >
            <div
              id={"wizard-step-#{@current_step}"}
              class={if(@step_direction == :forward, do: "wizard-step-forward", else: "wizard-step-backward")}
              role="group"
              aria-labelledby={"step-title-#{@current_step}"}
              aria-live="polite"
              phx-mounted={JS.focus_first()}
            >
              <h2 id={"step-title-#{@current_step}"} class="text-xl font-medium text-base-content mb-4">
                {@current_step}. {step_title(@current_step)}
              </h2>
              <.step_fields
                step={@current_step}
                form={@form}
                country_options={@country_options}
                city_name={@city_name}
                age={@age}
                last_params={@last_params}
              />
            </div>

            <div class="border-t border-base-300 pt-4 flex justify-between">
              <button
                :if={@current_step > 1}
                type="button"
                phx-click="prev_step"
                class="btn btn-ghost"
              >
                Zurück
              </button>
              <div :if={@current_step == 1} />

              <button
                :if={@current_step < 4}
                type="button"
                phx-click="next_step"
                class="btn btn-primary"
              >
                Weiter
              </button>
              <.button
                :if={@current_step == 4}
                phx-disable-with="Konto wird erstellt..."
                class="btn btn-primary"
              >
                Konto erstellen
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :current_step, :integer, required: true

  defp step_indicator(assigns) do
    ~H"""
    <div class="flex items-center justify-center mb-8">
      <div :for={step <- 1..4} class="flex items-center">
        <div class="flex flex-col items-center">
          <div class={[
            "w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium border-2 transition-colors",
            cond do
              step < @current_step -> "bg-primary border-primary text-primary-content"
              step == @current_step -> "border-primary text-primary bg-transparent"
              true -> "border-base-300 text-base-content/40 bg-transparent"
            end
          ]}>
            <svg
              :if={step < @current_step}
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                clip-rule="evenodd"
              />
            </svg>
            <span :if={step >= @current_step}>{step}</span>
          </div>
          <span class={[
            "text-xs mt-1 hidden sm:block",
            cond do
              step < @current_step -> "text-primary"
              step == @current_step -> "text-primary font-medium"
              true -> "text-base-content/40"
            end
          ]}>
            {step_title(step)}
          </span>
        </div>
        <div
          :if={step < 4}
          class={[
            "w-8 sm:w-12 h-0.5 mx-1 sm:mx-2",
            if(step < @current_step, do: "bg-primary", else: "bg-base-300")
          ]}
        />
      </div>
    </div>
    """
  end

  attr :step, :integer, required: true
  attr :form, :any, required: true
  attr :country_options, :list, default: []
  attr :city_name, :string, default: nil
  attr :age, :integer, default: nil
  attr :last_params, :map, default: %{}

  defp step_fields(%{step: 1} = assigns) do
    ~H"""
    <div class="space-y-4">
      <.input
        field={@form[:email]}
        type="email"
        label="E-Mail-Adresse"
        autocomplete="username"
        required
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
      <div>
        <.input
          field={@form[:birthday]}
          type="date"
          label="Geburtstag (mind. 18 Jahre)"
          required
        />
        <p :if={@age} class="text-xs text-base-content/50 mt-1 ml-1">
          {@age} Jahre alt
        </p>
      </div>
    </div>
    """
  end

  defp step_fields(%{step: 2} = assigns) do
    ~H"""
    <div class="space-y-4">
      <.input
        field={@form[:display_name]}
        type="text"
        label="Anzeigename (2-50 Zeichen)"
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
    """
  end

  defp step_fields(%{step: 3} = assigns) do
    ~H"""
    <div class="space-y-4">
      <.input
        field={@form[:country_id]}
        type="select"
        label="Land"
        options={@country_options}
        required
      />
      <div>
        <.input
          field={@form[:zip_code]}
          type="text"
          label="Postleitzahl (5 Ziffern)"
          required
        />
        <p :if={@city_name} class="text-xs text-base-content/50 mt-1 ml-1">
          {@city_name}
        </p>
      </div>
    </div>
    """
  end

  defp step_fields(%{step: 4} = assigns) do
    ~H"""
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
          field={@form[:partner_minimum_age]}
          type="number"
          label="Mindestalter Partner"
          min="18"
        />
        <.input
          field={@form[:partner_maximum_age]}
          type="number"
          label="Höchstalter Partner"
          min="18"
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
      <.input
        field={@form[:terms_accepted]}
        type="checkbox"
        label="Ich akzeptiere die Allgemeinen Geschäftsbedingungen und die Datenschutzerklärung."
        required
      />
    </div>
    """
  end

  defp step_title(step), do: @step_titles[step]

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

    socket =
      socket
      |> assign(country_options: country_options)
      |> assign(preferences_auto_filled: false)
      |> assign(current_step: 1)
      |> assign(step_direction: :forward)
      |> assign(last_params: initial_attrs)
      |> assign(city_name: nil)
      |> assign(age: compute_age(to_string(min_birthday)))
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current = socket.assigns.current_step
    params = socket.assigns.last_params

    if step_valid?(current, params) do
      next = current + 1
      {params, socket} = maybe_auto_fill_preferences(params, socket, next)
      city_name = lookup_city_name(params["zip_code"])
      age = compute_age(params["birthday"])

      changeset =
        Accounts.change_user_registration(%User{}, params)
        |> Map.put(:action, :validate)

      {:noreply,
       socket
       |> assign(current_step: next)
       |> assign(step_direction: :forward)
       |> assign(last_params: params)
       |> assign(city_name: city_name)
       |> assign(age: age)
       |> assign_form(changeset)}
    else
      changeset =
        Accounts.change_user_registration(%User{}, params)
        |> Map.put(:action, :validate)

      {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("prev_step", _params, socket) do
    prev = max(1, socket.assigns.current_step - 1)
    params = socket.assigns.last_params

    changeset =
      Accounts.change_user_registration(%User{}, params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(current_step: prev)
     |> assign(step_direction: :backward)
     |> assign_form(changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    merged_params = Map.merge(socket.assigns.last_params, user_params)

    case Accounts.register_user(merged_params) do
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
        error_step = step_with_first_error(changeset)

        {:noreply,
         socket
         |> assign(current_step: error_step)
         |> assign(step_direction: :backward)
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
         |> assign_form(changeset)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    merged_params = Map.merge(socket.assigns.last_params, user_params)
    city_name = lookup_city_name(merged_params["zip_code"])
    age = compute_age(merged_params["birthday"])

    changeset =
      Accounts.change_user_registration(%User{}, merged_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(last_params: merged_params)
     |> assign(city_name: city_name)
     |> assign(age: age)
     |> assign_form(changeset)}
  end

  @step_fields %{
    1 => ~w(email password mobile_phone birthday)a,
    2 => ~w(display_name gender height occupation language)a,
    3 => ~w(country_id zip_code)a,
    4 => ~w(preferred_partner_gender partner_minimum_age partner_maximum_age partner_height_min partner_height_max search_radius terms_accepted)a
  }

  defp step_with_first_error(changeset) do
    error_fields = changeset.errors |> Keyword.keys() |> MapSet.new()

    Enum.find(1..4, 4, fn step ->
      step_fields = @step_fields[step] |> MapSet.new()
      not MapSet.disjoint?(error_fields, step_fields)
    end)
  end

  defp step_valid?(step, params) do
    required = @step_required_fields[step]
    filled?(params, required)
  end

  defp maybe_auto_fill_preferences(params, socket, next_step) do
    if socket.assigns.preferences_auto_filled or next_step != 4 do
      {params, socket}
    else
      gender = params["gender"]
      height = parse_int(params["height"])
      age = compute_age(params["birthday"])

      if gender in ["male", "female", "diverse"] and is_integer(height) and is_integer(age) do
        params =
          params
          |> maybe_set_list("preferred_partner_gender", compute_preferred_gender(gender))
          |> maybe_set("partner_minimum_age", max(18, age - 5))
          |> maybe_set("partner_maximum_age", age + 5)
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

  defp compute_height_min("male", _height), do: 80
  defp compute_height_min("female", height), do: max(80, height - 5)
  defp compute_height_min("diverse", height), do: max(80, height - 15)

  defp compute_height_max("male", height), do: min(225, height + 5)
  defp compute_height_max("female", _height), do: 225
  defp compute_height_max("diverse", _height), do: 225

  defp filled?(params, keys) do
    Enum.all?(keys, fn key ->
      string_val = params[key]
      atom_val = params[String.to_atom(key)]
      val = string_val || atom_val
      val != nil and to_string(val) != ""
    end)
  end

  defp compute_age(birthday) when is_binary(birthday) do
    case Date.from_iso8601(birthday) do
      {:ok, date} ->
        today = Date.utc_today()
        age = today.year - date.year

        age =
          if {today.month, today.day} < {date.month, date.day},
            do: age - 1,
            else: age

        if age >= 0, do: age, else: nil

      _ ->
        nil
    end
  end

  defp compute_age(_), do: nil

  defp lookup_city_name(zip_code) when is_binary(zip_code) and byte_size(zip_code) == 5 do
    case GeoData.get_city_by_zip_code(zip_code) do
      %{name: name} -> name
      nil -> nil
    end
  end

  defp lookup_city_name(_), do: nil

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
