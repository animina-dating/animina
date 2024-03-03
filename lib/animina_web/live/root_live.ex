defmodule AniminaWeb.RootLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.BasicUser
  alias AniminaWeb.Registration
  alias AshPhoenix.Form

  @impl true
  def mount(_params, %{"language" => language} = session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(current_user: Registration.get_current_basic_user(session))
      |> assign(active_tab: :home)
      |> assign(trigger_action: false)
      |> assign(:errors, [])

    {:ok, socket}
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
        class="space-y-6 group"
        phx-change="validate"
        phx-submit="submit"
      >
        <div>
          <label for="user_username" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Username") %>
          </label>
          <div phx-feedback-for={f[:username].name} class="mt-2">
            <%= text_input(
              f,
              :username,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:username], :username) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Pusteblume1977"),
              value: f[:username].value,
              type: :text,
              required: true,
              autocomplete: :username,
              "phx-debounce": "200"
            ) %>

            <.error :for={msg <- get_field_errors(f[:username], :username)}>
              <%= gettext("Username") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <%= text_input(f, :hidden_points, type: :hidden, value: 200) %>
        <%= text_input(f, :language, type: :hidden, value: @language) %>

        <div>
          <label for="user_name" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Name") %>
          </label>
          <div phx-feedback-for={f[:name].name} class="mt-2">
            <%= text_input(f, :name,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:name], :name) == [],
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
          <label for="user_email" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("E-mail address") %>
          </label>
          <div phx-feedback-for={f[:email].name} class="mt-2">
            <%= text_input(f, :email,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:email], :email) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("alice@example.net"),
              value: f[:email].value,
              type: :email,
              required: true,
              autocomplete: :email,
              "phx-debounce": "200"
            ) %>

            <.error :for={msg <- get_field_errors(f[:email], :email)}>
              <%= gettext("E-mail address") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="user_password" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Password") %>
            </label>
          </div>
          <div phx-feedback-for={f[:password].name} class="mt-2">
            <%= password_input(f, :password,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:password], :password) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Password"),
              value: f[:password].value,
              autocomplete: "new-password",
              "phx-debounce": "blur"
            ) %>

            <.error :for={msg <- get_field_errors(f[:password], :password)}>
              <%= gettext("Password") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="user_birthday" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Date of birth") %>
            </label>
          </div>
          <div phx-feedback-for={f[:birthday].name} class="mt-2">
            <%= date_input(f, :birthday,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:birthday], :birthday) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: "",
              value: f[:birthday].value,
              autocomplete: "bday",
              "phx-debounce": "blur"
            ) %>

            <.error :for={msg <- get_field_errors(f[:birthday], :birthday)}>
              <%= gettext("Date of birth") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="user_gender" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Gender") %>
            </label>
          </div>
          <div class="mt-2" phx-no-format>

            <%
              item_code = "male"
              item_title = gettext("Male")
            %>
            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, item_code,
                id: "gender_" <> item_code,
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500",
                checked: true
              ) %>
              <%= label(f, :gender, item_title,
                for: "gender_" <> item_code,
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>

            <%
              item_code = "female"
              item_title = gettext("Female")
            %>
            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, item_code,
                id: "gender_" <> item_code,
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
              ) %>
              <%= label(f, :gender, item_title,
                for: "gender_" <> item_code,
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>

            <%
              item_code = "diverse"
              item_title = gettext("Diverse")
            %>
            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, item_code,
                id: "gender_" <> item_code,
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
              ) %>
              <%= label(f, :gender, item_title,
                for: "gender_" <> item_code,
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="user_zip_code" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Zip code") %>
            </label>
          </div>
          <div phx-feedback-for={f[:zip_code].name} class="mt-2">
            <%= text_input(f, :zip_code,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:zip_code], :zip_code) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              # Easter egg (Bundestag)
              placeholder: "11011",
              value: f[:zip_code].value,
              inputmode: "numeric",
              autocomplete: "postal-code",
              "phx-debounce": "blur"
            ) %>

            <.error :for={msg <- get_field_errors(f[:zip_code], :zip_code)}>
              <%= gettext("Zip code") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="user_height" class="block text-sm font-medium leading-6 text-gray-900">
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
                  unless(get_field_errors(f[:height], :height) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: "160",
              inputmode: "numeric",
              value: f[:height].value,
              "phx-debounce": "blur"
            ) %>

            <.error :for={msg <- get_field_errors(f[:height], :height)}>
              <%= gettext("Height") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="user_mobile_phone" class="block text-sm font-medium leading-6 text-gray-900">
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
                  unless(get_field_errors(f[:mobile_phone], :mobile_phone) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: "0151-12345678",
              inputmode: "numeric",
              value: f[:mobile_phone].value,
              "phx-debounce": "blur"
            ) %>

            <.error :for={msg <- get_field_errors(f[:mobile_phone], :mobile_phone)}>
              <%= gettext("Mobile phone number") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div class="relative flex gap-x-3">
          <div phx-feedback-for={f[:legal_terms_accepted].name} class="flex h-6 items-center">
            <%= checkbox(f, :legal_terms_accepted,
              class:
                "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:legal_terms_accepted], :legal_terms_accepted) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              value: f[:legal_terms_accepted].value,
              "phx-debounce": "200"
            ) %>
          </div>
          <div class="text-sm leading-6">
            <label for="comments" class="font-medium text-gray-900">
              <%= gettext("I accept the legal terms of animina.") %>
            </label>
            <p class="text-gray-500">
              <%= gettext("Warning: We will sell your data to the devel and Santa Claus.") %>
            </p>
            <.error :for={msg <- get_field_errors(f[:legal_terms_accepted], :legal_terms_accepted)}>
              <%= gettext("I accept the legal terms of animina") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <%= submit(@cta,
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@form.valid? == false,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.valid? == false
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
