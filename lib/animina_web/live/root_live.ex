defmodule AniminaWeb.RootLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.BasicUser
  alias AniminaWeb.Registration
  alias AshPhoenix.Form

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      :timer.send_interval(2500, self(), :tick)
    end

    socket =
      socket
      |> assign(points: 0)
      |> assign(current_user: Registration.get_current_basic_user(session))
      |> assign(active_tab: :home)
      |> assign(trigger_action: false)
      |> assign(today: Date.utc_today())

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    socket = assign(socket, points: socket.assigns.points + 1)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :register, _params) do
    socket
    |> assign(page_title: gettext("Animina dating app"))
    |> assign(:form_id, "sign-up-form")
    |> assign(:cta, gettext("Register new account"))
    |> assign(:action, ~p"/auth/user/password/register")
    |> assign(:hidden_points, 100)
    |> assign(
      :form,
      Form.for_create(BasicUser, :register_with_password, api: Accounts, as: "user")
    )
  end

  defp apply_action(socket, :sign_in, _params) do
    socket
    |> assign(:form_id, "sign-in-form")
    |> assign(:cta, gettext("Sign in"))
    |> assign(:action, ~p"/auth/user/password/sign_in")
    |> assign(
      :form,
      Form.for_action(BasicUser, :sign_in_with_password, api: Accounts, as: "user")
    )
  end

  @impl true
  def handle_event("validate", %{"user" => user}, socket) do
    form = Form.validate(socket.assigns.form, user, errors: true)

    {:noreply, socket |> assign(form: form)}
  end

  @impl true
  def handle_event("submit", %{"user" => user}, socket) do
    form = Form.validate(socket.assigns.form, user)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:errors, Form.errors(form))
      |> assign(:trigger_action, form.valid?)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 px-5">
      <.notification_box
        title={gettext("Animina Dating Plattform")}
        message={gettext("Fair, Fast and Free. Join us now!")}
        avatars_urls={[
          "/images/unsplash/men/prince-akachi-4Yv84VgQkRM-unsplash.jpg",
          "/images/unsplash/women/stefan-stefancik-QXevDflbl8A-unsplash.jpg"
        ]}
      />

      <.form
        :let={f}
        id="basic_user_form"
        for={@form}
        action={@action}
        phx-trigger-action={@trigger_action}
        method="POST"
        class="space-y-6"
        phx-change="validate"
        phx-submit="submit"
      >
        <div>
          <label for="username" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Username") %>
          </label>
          <div phx-feedback-for={f[:username].name} class="mt-2">
            <%= text_input(
              f,
              :username,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  if(get_field_errors(f[:username], :username) != [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: "Pusteblume1977",
              value: f[:username].value,
              type: :text,
              required: true,
              autofocus: true,
              autocomplete: :username
            ) %>

            <.error :for={msg <- get_field_errors(f[:username], :username)}>
              <%= gettext("Username") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <%= text_input(f, :hidden_points, type: :hidden, value: 200) %>

        <div>
          <label for="name" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Name") %>
          </label>
          <div phx-feedback-for={f[:name].name} class="mt-2">
            <%= text_input(f, :name,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  if(get_field_errors(f[:name], :name) != [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Alice"),
              value: f[:name].value,
              type: :text,
              required: true,
              autocomplete: "given-name"
            ) %>

            <.error :for={msg <- get_field_errors(f[:name], :name)}>
              <%= gettext("Name") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <label for="email" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("E-mail address") %>
          </label>
          <div phx-feedback-for={f[:email].name} class="mt-2">
            <%= text_input(f, :email,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  if(get_field_errors(f[:email], :email) != [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("alice@example.net"),
              value: f[:email].value,
              type: :email,
              required: true,
              autocomplete: :email
            ) %>

            <.error :for={msg <- get_field_errors(f[:email], :email)}>
              <%= gettext("E-mail address") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="password" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Password") %>
              <span class="text-gray-400">(<%= gettext("at least 8 characters") %>)</span>
            </label>
          </div>
          <div phx-feedback-for={f[:password].name} class="mt-2">
            <%= password_input(f, :password,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  if(get_field_errors(f[:password], :password) != [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Password"),
              value: f[:password].value,
              autocomplete: "new-password"
            ) %>

            <.error :for={msg <- get_field_errors(f[:password], :password)}>
              <%= gettext("Password") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="birthday" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Date of birth") %>
              <span class="text-gray-400">
                (<%= gettext("you have to be at least 18 years old") %>)
              </span>
            </label>
          </div>
          <div phx-feedback-for={f[:birthday].name} class="mt-2">
            <%= date_input(f, :birthday,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  if(get_field_errors(f[:birthday], :birthday) != [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: "",
              value:
                [
                  (@today.year - 20) |> Integer.to_string() |> String.pad_leading(4, "0"),
                  @today.month |> Integer.to_string() |> String.pad_leading(2, "0"),
                  @today.day |> Integer.to_string() |> String.pad_leading(2, "0")
                ]
                |> Enum.join("-"),
              autocomplete: "bday"
            ) %>

            <.error :for={msg <- get_field_errors(f[:birthday], :birthday)}>
              <%= gettext("Date of birth") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="gender" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Gender") %>
            </label>
          </div>
          <div class="mt-2">
            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, "male",
                id: "gender_male",
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500",
                checked: true
              ) %>
              <%= label(f, :gender, gettext("Male"),
                for: "gender_male",
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>

            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, "female",
                id: "gender_female",
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
              ) %>
              <%= label(f, :gender, gettext("Female"),
                for: "gender_female",
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>

            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, gettext("Diverse / non-binary"),
                id: "gender_divers",
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
              ) %>
              <%= label(f, :gender, "Diverse / non-binary",
                for: "gender_divers",
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="zip_code" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Postal code") %>
              <span class="text-gray-400">
                (<%= gettext("5-digit postal code in Germany") %>)
              </span>
            </label>
          </div>
          <div phx-feedback-for={f[:zip_code].name} class="mt-2">
            <%= text_input(f, :zip_code,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  if(get_field_errors(f[:zip_code], :zip_code) != [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              # Postal code of the Bundestag :-)
              placeholder: "11011",
              value: f[:zip_code].value,
              autocomplete: "postal-code"
            ) %>

            <.error :for={msg <- get_field_errors(f[:zip_code], :zip_code)}>
              <%= gettext("Postal code") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="height" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Height") %>
              <span class="text-gray-400">
                (<%= gettext("in cm") %>)
              </span>
            </label>
          </div>

          <div phx-feedback-for={f[:height].name} class="mt-2">
            <%= text_input(f, :height,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  if(get_field_errors(f[:height], :height) != [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: "160",
              value: f[:height].value
            ) %>

            <.error :for={msg <- get_field_errors(f[:height], :height)}>
              <%= gettext("Height") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="mobile_phone" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Mobile phone number") %>
              <span class="text-gray-400">
                (<%= gettext("to receive a verification code") %>)
              </span>
            </label>
          </div>
          <div phx-feedback-for={f[:mobile_phone].name} class="mt-2">
            <%= text_input(f, :mobile_phone,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  if(get_field_errors(f[:mobile_phone], :mobile_phone) != [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: "0151-12345678",
              value: f[:mobile_phone].value
            ) %>

            <.error :for={msg <- get_field_errors(f[:mobile_phone], :mobile_phone)}>
              <%= gettext("Mobile phone number") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <%= submit(@cta,
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end
end
