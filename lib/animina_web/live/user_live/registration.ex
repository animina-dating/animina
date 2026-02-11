defmodule AniminaWeb.UserLive.Registration do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.GenderGuesser
  alias Animina.Accounts.User
  alias Animina.ActivityLog
  alias Animina.GeoData

  @step_params %{1 => "account", 2 => "profile", 3 => "location", 4 => "partner"}

  defp step_titles do
    %{
      1 => gettext("Account"),
      2 => gettext("Profile"),
      3 => gettext("Location"),
      4 => gettext("Ideal Partner")
    }
  end

  @step_required_fields %{
    1 => ~w(first_name last_name email password mobile_phone birthday),
    2 => ~w(display_name gender height),
    3 => :locations,
    4 => []
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      display_name={navbar_display_name(@current_step, @last_params)}
    >
      <div class="max-w-2xl mx-auto">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Secure your spot")}
            </h1>
            <p class="mt-3 text-sm text-base-content/70 max-w-md mx-auto">
              {ngettext(
                "We activate new accounts in regional waves to ensure the best experience. Set up your profile now — you'll get your GO within %{count} day at most. Invite %{referral_threshold} friends with your referral code to skip ahead!",
                "We activate new accounts in regional waves to ensure the best experience. Set up your profile now — you'll get your GO within %{count} days at most. Invite %{referral_threshold} friends with your referral code to skip ahead!",
                @max_waitlist_days,
                referral_threshold: @referral_threshold
              )}
            </p>
            <p class="mt-2 text-base text-base-content/70">
              {gettext("Already registered?")}
              <.link navigate={~p"/users/log-in"} class="font-semibold text-primary hover:underline">
                {gettext("Log in now")}
              </.link>
            </p>
          </div>

          <.step_indicator current_step={@current_step} location_count={length(@locations)} />

          <.form
            for={@form}
            id="registration_form"
            action={~p"/users/register"}
            phx-submit="save"
            phx-change="validate"
            class="space-y-6"
          >
            <div
              id={"wizard-step-#{@current_step}"}
              class={
                if(@step_direction == :forward,
                  do: "wizard-step-forward",
                  else: "wizard-step-backward"
                )
              }
              role="group"
              aria-labelledby={"step-title-#{@current_step}"}
              aria-live="polite"
              phx-mounted={JS.focus_first()}
            >
              <h2
                id={"step-title-#{@current_step}"}
                class="text-xl font-medium text-base-content mb-4"
              >
                {@current_step}. {step_title(@current_step, length(@locations))}
              </h2>
              <.step_fields
                step={@current_step}
                form={@form}
                country_options={@country_options}
                locations={@locations}
                location_input={@location_input}
                age={@age}
                last_params={@last_params}
                max_birthday={@max_birthday}
              />
            </div>

            <div class="border-t border-base-300 pt-4 flex justify-between">
              <button
                :if={@current_step > 1}
                type="button"
                phx-click="prev_step"
                class="btn btn-ghost"
              >
                {gettext("Back")}
              </button>
              <div :if={@current_step == 1} />

              <button
                :if={@current_step < 4}
                type="button"
                phx-click="next_step"
                disabled={not @step_ready}
                class={["btn btn-primary", if(not @step_ready, do: "btn-disabled")]}
              >
                {gettext("Next")}
              </button>
              <.button
                :if={@current_step == 4}
                phx-disable-with={gettext("Securing your spot...")}
                class="btn btn-primary"
              >
                {gettext("Secure your spot")}
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :current_step, :integer, required: true
  attr :location_count, :integer, default: 1

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
            {step_title(step, @location_count)}
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
  attr :locations, :list, default: []
  attr :location_input, :map, default: %{}
  attr :age, :integer, default: nil
  attr :last_params, :map, default: %{}
  attr :max_birthday, :string, default: nil

  defp step_fields(%{step: 1} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="grid grid-cols-2 gap-4">
        <.input
          field={@form[:first_name]}
          type="text"
          label={gettext("First name")}
          autocomplete="given-name"
          required
          phx-blur="guess_gender"
        />
        <.input
          field={@form[:last_name]}
          type="text"
          label={gettext("Last name")}
          autocomplete="family-name"
          required
        />
      </div>
      <.input
        field={@form[:email]}
        type="email"
        label={gettext("Email address")}
        autocomplete="email"
        required
      />
      <.input
        field={@form[:password]}
        type="password"
        label={gettext("Password (min. 12 characters)")}
        autocomplete="new-password"
        required
      />
      <.input
        field={@form[:mobile_phone]}
        type="tel"
        label={gettext("Mobile phone (e.g. +491514567890)")}
        required
        phx-blur="normalize_phone"
      />
      <div>
        <.input
          field={@form[:birthday]}
          type="date"
          label={gettext("Birthday (min. 18 years)")}
          autocomplete="bday"
          max={@max_birthday}
          required
        />
        <p :if={@age} class="text-xs text-base-content/50 mt-1 ms-1">
          {gettext("%{age} years old", age: @age)}
        </p>
      </div>
      <.input
        field={@form[:referral_code_input]}
        type="text"
        label={gettext("Referral code (optional)")}
        placeholder={gettext("e.g. A7X3K9")}
        autocomplete="off"
        maxlength="6"
      />
    </div>
    """
  end

  defp step_fields(%{step: 2} = assigns) do
    ~H"""
    <div class="space-y-4">
      <.input
        field={@form[:display_name]}
        type="text"
        label={gettext("Display name (2-50 characters)")}
        autocomplete="off"
        required
      />
      <.input
        field={@form[:gender]}
        type="radio"
        label={gettext("Gender")}
        options={[
          {gettext("Male"), "male"},
          {gettext("Female"), "female"},
          {gettext("Diverse"), "diverse"}
        ]}
        required
      />
      <.input
        field={@form[:height]}
        type="number"
        label={gettext("Height in cm (80-225)")}
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
        options={[
          {"Deutsch", "de"},
          {"English", "en"},
          {"Türkçe", "tr"},
          {"Русский", "ru"},
          {"العربية", "ar"},
          {"Polski", "pl"},
          {"Français", "fr"},
          {"Español", "es"},
          {"Українська", "uk"}
        ]}
      />
    </div>
    """
  end

  defp step_fields(%{step: 3} = assigns) do
    ~H"""
    <div class="space-y-4">
      <%!-- Saved locations list --%>
      <div :if={@locations != []} class="space-y-2">
        <div
          :for={loc <- @locations}
          id={"saved-location-#{loc.id}"}
          class="flex items-center justify-between bg-base-200 rounded-lg px-4 py-3"
        >
          <div class="flex items-center gap-3">
            <span class="text-sm font-medium">{country_name(@country_options, loc.country_id)}</span>
            <span class="whitespace-nowrap">
              <span class="text-sm text-base-content/70">{loc.zip_code}</span>
              <span :if={loc.city_name} class="text-sm text-base-content/50">{loc.city_name}</span>
            </span>
          </div>
          <button
            type="button"
            phx-click="remove_location"
            phx-value-id={loc.id}
            class="btn btn-ghost btn-xs btn-circle"
            aria-label={gettext("Remove location")}
          >
            &times;
          </button>
        </div>
      </div>

      <%!-- Input form to add a new location --%>
      <div :if={length(@locations) < 4} class="border border-base-300 rounded-lg p-4 space-y-3">
        <div class="fieldset">
          <label class="label" for="location_input_country_id">{gettext("Country")}</label>
          <select
            id="location_input_country_id"
            name="user[location_input][country_id]"
            class="select select-bordered w-full"
          >
            <option
              :for={{label, value} <- @country_options}
              value={value}
              selected={value == @location_input.country_id}
            >
              {label}
            </option>
          </select>
        </div>
        <div>
          <div class="fieldset">
            <label class="label" for="location_input_zip_code">
              {gettext("Zip code (5 digits)")}
            </label>
            <input
              type="text"
              id="location_input_zip_code"
              name="user[location_input][zip_code]"
              value={@location_input.zip_code}
              class="input input-bordered w-full"
            />
          </div>
          <p
            :if={@location_input.city_name && !@location_input.error}
            class="text-xs text-base-content/50 mt-1 ms-1"
          >
            {@location_input.city_name}
          </p>
          <p :if={@location_input.error} class="text-xs text-error mt-1 ms-1">
            {@location_input.error}
          </p>
        </div>
        <button
          type="button"
          phx-click="add_location"
          disabled={not location_input_addable?(@location_input)}
          class={[
            "btn btn-outline btn-sm w-full",
            if(not location_input_addable?(@location_input), do: "btn-disabled")
          ]}
        >
          {gettext("Add location %{number}", number: length(@locations) + 2)}
        </button>
      </div>

      <p :if={length(@locations) >= 4} class="text-sm text-base-content/50 text-center">
        {gettext("Maximum of 4 locations reached.")}
      </p>
    </div>
    """
  end

  defp step_fields(%{step: 4} = assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="fieldset mb-2">
        <span class="label mb-1">{gettext("Gender(s)")}</span>
        <input type="hidden" name="user[preferred_partner_gender][]" value="" />
        <div class="flex gap-4">
          <label
            :for={
              {label, value} <- [
                {gettext("Male"), "male"},
                {gettext("Female"), "female"},
                {gettext("Diverse"), "diverse"}
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
      <div class="grid grid-cols-2 gap-4">
        <.input
          field={@form[:partner_minimum_age]}
          type="number"
          label={gettext("Minimum age")}
          min="18"
        />
        <.input
          field={@form[:partner_maximum_age]}
          type="number"
          label={gettext("Maximum age")}
          min="18"
        />
      </div>
      <div class="grid grid-cols-2 gap-4">
        <.input
          field={@form[:partner_height_min]}
          type="number"
          label={gettext("Minimum height (cm)")}
          min="80"
          max="225"
        />
        <.input
          field={@form[:partner_height_max]}
          type="number"
          label={gettext("Maximum height (cm)")}
          min="80"
          max="225"
        />
      </div>
      <.input
        field={@form[:search_radius]}
        type="number"
        label={gettext("Search radius (km)")}
        min="1"
      />
      <div class="flex items-start gap-3">
        <input
          type="checkbox"
          id={@form[:terms_accepted].id}
          name={@form[:terms_accepted].name}
          value="true"
          checked={Phoenix.HTML.Form.normalize_value("checkbox", @form[:terms_accepted].value)}
          required
          class="checkbox checkbox-sm mt-1"
        />
        <label for={@form[:terms_accepted].id} class="text-sm text-base-content/70">
          {gettext("I accept the")}
          <a href="/datenschutz" class="text-primary hover:underline" target="_blank">
            {gettext("Privacy Policy")}
          </a>
          {gettext("and the")}
          <a href="/agb" class="text-primary hover:underline" target="_blank">{gettext("Terms of Service")}</a>.
        </label>
      </div>
    </div>
    """
  end

  defp step_title(3, count) when count > 1, do: gettext("Locations")
  defp step_title(step, _count), do: step_titles()[step]

  defp navbar_display_name(step, params) when step >= 3 do
    case params["display_name"] do
      name when is_binary(name) and name != "" -> name
      _ -> nil
    end
  end

  defp navbar_display_name(_step, _params), do: nil

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

    default_country_id = if(germany, do: germany.id, else: nil)

    initial_location_input = %{
      country_id: default_country_id,
      zip_code: "",
      city_name: nil,
      error: nil
    }

    initial_attrs =
      %{
        "birthday" => min_birthday,
        "gender" => "male",
        "height" => 170,
        "language" => socket.assigns.locale,
        "preferred_partner_gender" => ["female"]
      }

    changeset = Accounts.change_user_registration(%User{}, initial_attrs)

    socket =
      socket
      |> assign(page_title: gettext("Secure Your Spot"))
      |> assign(max_waitlist_days: Animina.FeatureFlags.waitlist_duration_days() + 1)
      |> assign(referral_threshold: Animina.FeatureFlags.referral_threshold())
      |> assign(country_options: country_options)
      |> assign(preferences_auto_filled: false)
      |> assign(guessed_gender: nil)
      |> assign(guessed_first_name: nil)
      |> assign(current_step: 1)
      |> assign(step_direction: :forward)
      |> assign(last_params: initial_attrs)
      |> assign(locations: [])
      |> assign(next_location_id: 1)
      |> assign(location_input: initial_location_input)
      |> assign(step_ready: false)
      |> assign(age: compute_age(to_string(min_birthday)))
      |> assign(max_birthday: to_string(min_birthday))
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Only apply URL step param on initial load or when navigating back via browser
    # Don't override step during next_step/prev_step events (those use push_patch)
    step = step_from_param(params["step"])

    {:noreply,
     socket
     |> assign(current_step: step)
     |> recalc_step_ready()}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current = socket.assigns.current_step
    params = socket.assigns.last_params

    # Auto-add pending location input when advancing from step 3
    socket = maybe_auto_add_location_input(current, socket)

    if step_valid?(current, params, socket.assigns.locations) do
      step_name = @step_params[current]

      ActivityLog.log(
        "profile",
        "registration_step_completed",
        "Registration step '#{step_name}' completed",
        metadata: %{"step" => step_name}
      )

      next = current + 1
      {params, socket} = maybe_prefill_step_2(params, socket, current, next)
      {params, socket} = maybe_auto_fill_preferences(params, socket, next)
      age = compute_age(params["birthday"])

      changeset =
        Accounts.change_user_registration(%User{}, params)
        |> Map.put(:action, :validate)

      {:noreply,
       socket
       |> assign(step_direction: :forward)
       |> assign(last_params: params)
       |> assign(age: age)
       |> assign_form(changeset)
       |> push_patch(to: registration_path(next))}
    else
      changeset =
        Accounts.change_user_registration(%User{}, params)
        |> Map.put(:action, :validate)

      {:noreply,
       socket
       |> assign_form(changeset)
       |> recalc_step_ready()}
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
     |> assign(step_direction: :backward)
     |> assign_form(changeset)
     |> push_patch(to: registration_path(prev))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    merged_params = Map.merge(socket.assigns.last_params, user_params)

    locations_for_save =
      socket.assigns.locations
      |> Enum.map(fn loc -> %{"country_id" => loc.country_id, "zip_code" => loc.zip_code} end)

    save_params = Map.put(merged_params, "locations", locations_for_save)

    case Accounts.register_user(save_params) do
      {:ok, user} ->
        {:ok, _pin} = Accounts.send_confirmation_pin(user)
        token = Phoenix.Token.sign(AniminaWeb.Endpoint, "pin_confirmation", user.id)

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("A confirmation code has been sent to %{email}.", email: user.email)
         )
         |> push_navigate(to: ~p"/users/confirm/#{token}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        if Accounts.only_email_uniqueness_error?(changeset) do
          # Phantom flow: pretend registration succeeded to protect email privacy
          email = Ecto.Changeset.get_field(changeset, :email)
          Accounts.UserNotifier.deliver_duplicate_registration_warning(email)

          token =
            Phoenix.Token.sign(
              AniminaWeb.Endpoint,
              "pin_confirmation",
              {:phantom, Ecto.UUID.generate(), email}
            )

          {:noreply,
           socket
           |> put_flash(
             :info,
             gettext("A confirmation code has been sent to %{email}.", email: email)
           )
           |> push_navigate(to: ~p"/users/confirm/#{token}")}
        else
          # Strip email uniqueness error if present alongside other errors
          cleaned_changeset = strip_email_uniqueness_error(changeset)

          error_step = step_with_first_error(cleaned_changeset)

          {:noreply,
           socket
           |> assign(step_direction: :backward)
           |> assign_form(cleaned_changeset)
           |> push_patch(to: registration_path(error_step))}
        end
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
         |> assign_form(changeset)
         |> recalc_step_ready()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("guess_gender", %{"value" => name}, socket) do
    name = String.trim(name)

    if name != "" and name != socket.assigns.guessed_first_name do
      GenderGuesser.guess_async(name, self())
      {:noreply, assign(socket, guessed_first_name: name)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("add_location", _params, socket) do
    locations = socket.assigns.locations
    input = socket.assigns.location_input

    cond do
      length(locations) >= 4 ->
        {:noreply, socket}

      not Regex.match?(~r/^\d{5}$/, input.zip_code || "") ->
        {:noreply,
         socket
         |> assign(
           location_input: %{input | error: gettext("Please enter a valid 5-digit zip code")}
         )}

      is_nil(lookup_city_name(input.zip_code)) ->
        {:noreply,
         socket
         |> assign(location_input: %{input | error: gettext("This is not a valid zip code")})}

      Enum.any?(locations, fn loc ->
        loc.country_id == input.country_id and loc.zip_code == input.zip_code
      end) ->
        {:noreply,
         socket
         |> assign(
           location_input: %{input | error: gettext("This location has already been added")}
         )}

      true ->
        new_location = %{
          id: socket.assigns.next_location_id,
          country_id: input.country_id,
          zip_code: input.zip_code,
          city_name: lookup_city_name(input.zip_code),
          error: nil
        }

        {:noreply,
         socket
         |> assign(locations: locations ++ [new_location])
         |> assign(next_location_id: socket.assigns.next_location_id + 1)
         |> assign(
           location_input: %{
             country_id: input.country_id,
             zip_code: "",
             city_name: nil,
             error: nil
           }
         )
         |> recalc_step_ready()}
    end
  end

  def handle_event("remove_location", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    updated = Enum.reject(socket.assigns.locations, &(&1.id == id))
    input = socket.assigns.location_input

    {:noreply,
     socket
     |> assign(locations: updated)
     |> assign(location_input: %{input | error: nil})
     |> recalc_step_ready()}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    merged_params =
      socket.assigns.last_params
      |> Map.reject(fn {k, _} -> is_binary(k) and String.starts_with?(k, "_unused_") end)
      |> Map.merge(user_params)

    age = compute_age(merged_params["birthday"])

    # Update location input from form params
    socket = update_location_input_from_params(socket, user_params)

    changeset =
      Accounts.change_user_registration(%User{}, merged_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(last_params: merged_params)
     |> assign(age: age)
     |> assign_form(changeset)
     |> recalc_step_ready()}
  end

  @impl true
  def handle_info({:gender_guess_result, gender}, socket) do
    {:noreply, assign(socket, guessed_gender: gender)}
  end

  defp update_location_input_from_params(socket, user_params) do
    case user_params["location_input"] do
      nil ->
        socket

      params ->
        input = socket.assigns.location_input
        zip_code = params["zip_code"] || input.zip_code
        country_id = params["country_id"] || input.country_id
        city_name = lookup_city_name(zip_code)

        error =
          if Regex.match?(~r/^\d{5}$/, zip_code || "") and is_nil(city_name) do
            gettext("This is not a valid zip code")
          end

        assign(socket,
          location_input: %{
            input
            | zip_code: zip_code,
              country_id: country_id,
              city_name: city_name,
              error: error
          }
        )
    end
  end

  @step_fields %{
    1 => ~w(first_name last_name email password mobile_phone birthday referral_code_input)a,
    2 => ~w(display_name gender height occupation language)a,
    3 => [],
    4 =>
      ~w(preferred_partner_gender partner_minimum_age partner_maximum_age partner_height_min partner_height_max search_radius terms_accepted)a
  }

  defp step_with_first_error(changeset) do
    error_fields = changeset.errors |> Keyword.keys() |> MapSet.new()

    Enum.find(1..4, 4, fn step ->
      step_fields = @step_fields[step] |> MapSet.new()
      not MapSet.disjoint?(error_fields, step_fields)
    end)
  end

  defp step_valid?(3, _params, locations) do
    locations != []
  end

  defp step_valid?(step, params, _locations) do
    required = @step_required_fields[step]
    filled?(params, required)
  end

  defp maybe_auto_add_location_input(3, socket) do
    input = socket.assigns.location_input
    locations = socket.assigns.locations

    if location_input_valid?(input, locations) do
      new_location = %{
        id: socket.assigns.next_location_id,
        country_id: input.country_id,
        zip_code: input.zip_code,
        city_name: lookup_city_name(input.zip_code),
        error: nil
      }

      socket
      |> assign(locations: locations ++ [new_location])
      |> assign(next_location_id: socket.assigns.next_location_id + 1)
      |> assign(
        location_input: %{country_id: input.country_id, zip_code: "", city_name: nil, error: nil}
      )
    else
      socket
    end
  end

  defp maybe_auto_add_location_input(_step, socket), do: socket

  defp location_input_valid?(input, locations) do
    location_input_addable?(input) and
      not Enum.any?(locations, fn loc ->
        loc.country_id == input.country_id and loc.zip_code == input.zip_code
      end)
  end

  defp location_input_addable?(input) do
    Regex.match?(~r/^\d{5}$/, input.zip_code || "") and
      input.country_id != nil and
      input.city_name != nil
  end

  defp maybe_prefill_step_2(params, socket, 1, 2) do
    first_name = params["first_name"]
    params = prefill_display_name(params, first_name)
    gender = resolve_guessed_gender(socket.assigns.guessed_gender, first_name)
    apply_guessed_gender(params, socket, gender)
  end

  defp maybe_prefill_step_2(params, socket, _from, _to), do: {params, socket}

  defp prefill_display_name(params, first_name) do
    if is_nil(params["display_name"]) or params["display_name"] == "" do
      Map.put(params, "display_name", first_name)
    else
      params
    end
  end

  defp resolve_guessed_gender(guessed, _first_name) when not is_nil(guessed), do: guessed

  defp resolve_guessed_gender(nil, first_name) when is_binary(first_name) and first_name != "" do
    case GenderGuesser.guess_from_cache(first_name) do
      {:ok, g} -> g
      :miss -> nil
    end
  end

  defp resolve_guessed_gender(nil, _first_name), do: nil

  defp apply_guessed_gender(params, socket, gender)
       when not is_nil(gender) do
    if gender != params["gender"] do
      params =
        params
        |> Map.put("gender", gender)
        |> Map.put("preferred_partner_gender", [""])

      {params, assign(socket, preferences_auto_filled: false)}
    else
      {params, socket}
    end
  end

  defp apply_guessed_gender(params, socket, nil), do: {params, socket}

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
        age = Animina.Accounts.compute_age(date)
        if age && age >= 0, do: age, else: nil

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

  defp country_name(country_options, country_id) do
    case Enum.find(country_options, fn {_label, id} -> id == country_id end) do
      {label, _} -> label
      nil -> ""
    end
  end

  defp recalc_step_ready(socket) do
    assign(socket, step_ready: compute_step_ready(socket))
  end

  defp compute_step_ready(socket) do
    step = socket.assigns.current_step
    params = socket.assigns.last_params
    locations = socket.assigns.locations

    case step do
      3 ->
        locations != [] or
          location_input_valid?(socket.assigns.location_input, locations)

      _ ->
        required = @step_required_fields[step]
        changeset = Accounts.change_user_registration(%User{}, params)
        step_atoms = Enum.map(required, &String.to_atom/1)
        error_keys = changeset.errors |> Keyword.keys() |> MapSet.new()
        step_set = MapSet.new(step_atoms)

        filled?(params, required) and MapSet.disjoint?(error_keys, step_set)
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end

  defp registration_path(step) do
    ~p"/users/register?step=#{@step_params[step]}"
  end

  defp step_from_param("profile"), do: 2
  defp step_from_param("location"), do: 3
  defp step_from_param("partner"), do: 4
  defp step_from_param(_), do: 1

  defp strip_email_uniqueness_error(changeset) do
    if Accounts.email_uniqueness_error?(changeset) do
      %{
        changeset
        | errors:
            Enum.reject(changeset.errors, fn {field, {_msg, meta}} ->
              field == :email and
                (meta[:validation] == :unsafe_unique or meta[:constraint] == :unique)
            end)
      }
    else
      changeset
    end
  end
end
