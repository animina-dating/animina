defmodule AniminaWeb.RootLive do
  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Accounts.User
  alias Animina.GenServers.ProfileViewCredits
  alias AshPhoenix.Form

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(current_user: nil)
      |> assign(trigger_action: false)
      |> assign(current_user_credit_points: 0)
      |> assign(:errors, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :register, params) do
    socket
    |> assign(page_title: gettext("Animina dating app"))
    |> assign(:form_id, "sign-up-form")
    |> assign(:cta, gettext("Register new account"))
    |> assign(active_tab: :register)
    |> assign(page_title: "Animina #{gettext("Register")}")
    |> assign(:action, get_link("/auth/user/password/register/", params))
    |> assign(:sign_in_link, get_link("/sign-in/", params))
    |> assign(:hidden_points, 100)
    |> assign(
      :form,
      Form.for_create(User, :register_with_password, domain: Accounts, as: "user")
    )
  end

  defp apply_action(socket, :sign_in, params) do
    socket
    |> assign(:form_id, "sign-in-form")
    |> assign(:cta, gettext("Sign in"))
    |> assign(active_tab: :sign_in)
    |> assign(page_title: "Animina #{gettext("Login")}")
    |> assign(:sign_up_link, get_link("/", params))
    |> assign(:action, get_link("/auth/user/sign_in/", params))
    |> assign(
      :form,
      Form.for_action(User, :custom_sign_in, domain: Accounts, as: "user")
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

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:errors, Form.errors(form))
     |> assign(:trigger_action, form.valid?)}
  end

  @impl true
  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-5 space-y-10">
      <%= if @form_id == "sign-up-form" do %>
        <.notification_box
          message={
            gettext(
              "Our competitors charge monthly, even if you don’t find a match. We only charge €20 after you find yours. And it's free for beta testers! 🎉"
            )
          }
          avatars_urls={[
            "/images/unsplash/men/prince-akachi-4Yv84VgQkRM-unsplash.jpg",
            "/images/unsplash/women/stefan-stefancik-QXevDflbl8A-unsplash.jpg"
          ]}
        />
      <% end %>

      <%= if @form_id == "sign-in-form" do %>
        <h1 class="text-4xl font-semibold dark:text-white"><%= gettext("Login") %></h1>
      <% end %>

      <.form
        :let={f}
        :if={@form_id == "sign-up-form"}
        id="basic_user_form"
        for={@form}
        action={@action}
        phx-trigger-action={@trigger_action}
        method="POST"
        class="space-y-6 group "
        phx-change="validate"
        phx-submit="submit"
      >
        <div class="w-[100%] md:grid grid-cols-2 gap-8">
          <div>
            <label
              for="user_username"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= gettext("Username") %>
            </label>
            <div phx-feedback-for={f[:username].name} class="mt-2">
              <%= text_input(
                f,
                :username,
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
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

          <%= text_input(f, :language, type: :hidden, value: @language) %>

          <div>
            <label
              for="user_name"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= gettext("Name") %>
            </label>
            <div phx-feedback-for={f[:name].name} class="mt-2">
              <%= text_input(f, :name,
                class:
                  "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
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
            <label
              for="user_email"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= gettext("E-mail address") %>
            </label>
            <div phx-feedback-for={f[:email].name} class="mt-2">
              <%= text_input(f, :email,
                class:
                  "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700  dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:email], :email) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                placeholder: gettext("alice@example.net"),
                value: f[:email].value,
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
              <label
                for="user_password"
                class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
              >
                <%= gettext("Password") %>
              </label>
            </div>
            <div phx-feedback-for={f[:password].name} class="mt-2">
              <%= password_input(f, :password,
                class:
                  "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:password], :password) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                placeholder: gettext("Password"),
                value: f[:password].value,
                autocomplete: gettext("new password"),
                "phx-debounce": "blur"
              ) %>

              <.error :for={msg <- get_field_errors(f[:password], :password)}>
                <%= gettext("Password") <> " " <> msg %>
              </.error>
            </div>
          </div>
        </div>

        <div class="w-[100%] md:grid grid-cols-2 gap-8">
          <div>
            <label
              for="user_birthday"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= gettext("Date of birth") %>
            </label>

            <div phx-feedback-for={f[:birthday].name} class="mt-2">
              <%= date_input(f, :birthday,
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white dark:[color-scheme:dark] shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:birthday], :birthday) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                placeholder: "",
                value: f[:birthday].value,
                autocomplete: gettext("bday"),
                "phx-debounce": "blur"
              ) %>

              <.error :for={msg <- get_field_errors(f[:birthday], :birthday)}>
                <%= gettext("Date of birth") <> " " <> msg %>
              </.error>
            </div>
          </div>
          <div>
            <label
              for="user_country"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= gettext("Country") %>
            </label>
            <div phx-feedback-for={f[:country].name} class="mt-2">
              <%= select(
                f,
                :country,
                ["Germany"],
                prompt: gettext("Select your country"),
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:country], :country) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                autofocus: true
              ) %>

              <.error :for={msg <- get_field_errors(f[:country], :country)}>
                <%= gettext("Country") <> " " <> msg %>
              </.error>
            </div>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label
              for="user_gender"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
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
                class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
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
                class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
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
                class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
              ) %>
            </div>
          </div>
        </div>
        <div class="w-[100%] md:grid grid-cols-2 gap-8">
          <div>
            <label
              for="user_occupation"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= gettext("Occupation") %>
            </label>
            <div phx-feedback-for={f[:occupation].name} class="mt-2">
              <%= text_input(f, :occupation,
                class:
                  "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:occupation], :name) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                placeholder: gettext("Dating Coach"),
                value: f[:occupation].value,
                type: :text,
                required: false,
                autocomplete: "organization-title"
              ) %>

              <.error :for={msg <- get_field_errors(f[:occupation], :name)}>
                <%= gettext("Occupation") <> " " <> msg %>
              </.error>
            </div>
          </div>

          <div>
            <div class="flex items-center justify-between">
              <label
                for="user_zip_code"
                class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
              >
                <%= gettext("Zip code") %>
              </label>
            </div>
            <div phx-feedback-for={f[:zip_code].name} class="mt-2">
              <%= text_input(f, :zip_code,
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:zip_code], :zip_code) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                # Easter egg (Bundestag)
                placeholder: "11011",
                value: f[:zip_code].value,
                inputmode: "numeric",
                autocomplete: gettext("postal code"),
                "phx-debounce": "blur"
              ) %>

              <.error :for={msg <- get_field_errors(f[:zip_code], :zip_code)}>
                <%= gettext("Zip code") <> " " <> msg %>
              </.error>
            </div>
          </div>

          <div>
            <div class="flex items-center justify-between">
              <label
                for="user_height"
                class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
              >
                <%= gettext("Height") %>
                <span class="text-gray-400 dark:text-gray-100">
                  (<%= gettext("in cm") %>)
                </span>
              </label>
            </div>
            <div phx-feedback-for={f[:height].name} class="mt-2">
              <%= text_input(f, :height,
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900  dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
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
              <label
                for="user_mobile_phone"
                class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
              >
                <%= gettext("Mobile phone number") %>
                <span class="text-gray-400 dark:text-gray-100">
                  (<%= gettext("to receive a verification code") %>)
                </span>
              </label>
            </div>
            <div phx-feedback-for={f[:mobile_phone].name} class="mt-2">
              <%= text_input(f, :mobile_phone,
                class:
                  "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm dark:bg-gray-700 dark:text-white ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
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
        </div>

        <div class="relative flex gap-x-3">
          <div phx-feedback-for={f[:legal_terms_accepted].name} class="flex items-center h-6">
            <%= checkbox(f, :legal_terms_accepted,
              class:
                "h-4 w-4 rounded border-gray-300 text-indigo-600  focus:ring-indigo-600 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:legal_terms_accepted], :legal_terms_accepted) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              value: f[:legal_terms_accepted].value,
              "phx-debounce": "200"
            ) %>
          </div>
          <div class="text-sm leading-6">
            <label for="comments" class="font-medium text-gray-900 dark:text-white">
              <%= gettext("I accept the legal terms of animina.") %>
            </label>
            <p class="text-gray-500 dark:text-gray-100">
              <%= gettext(
                "Warning: We will sell your data to the Devil and Santa Claus. Seriously, if you don't trust us, a dating platform is not a good place to share your personal information."
              ) %>
            </p>
            <.error :for={msg <- get_field_errors(f[:legal_terms_accepted], :legal_terms_accepted)}>
              <%= gettext("I accept the legal terms of animina") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <.link navigate={@sign_in_link}>
            <p class="block text-sm leading-6 text-gray-700 dark:text-white hover:text-gray-900 dark:hover:text-gray-100 hover:cursor-pointer hover:underline">
              <%= gettext("Already have an account? Sign in") %>
            </p>
          </.link>
        </div>

        <div>
          <%= submit(@cta,
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@form.valid? == false,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.valid? == false
          ) %>
        </div>
      </.form>

      <.form
        :let={f}
        :if={@form_id == "sign-in-form"}
        id="basic_user_sign_in_form"
        for={@form}
        action={@action}
        phx-trigger-action={@trigger_action}
        method="POST"
        class="space-y-6 group"
        phx-change="validate"
        phx-submit="submit"
      >
        <div>
          <label
            for="user_email"
            class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
          >
            <%= gettext("E-mail address or Username") %>
          </label>
          <div phx-feedback-for={f[:username_or_email].name} class="mt-2">
            <%= text_input(f, :username_or_email,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white  shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:username_or_email], :username_or_email) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("alice@example.net or alice"),
              value: f[:username_or_email].value,
              required: true,
              autocomplete: :username_or_email,
              "phx-debounce": "200"
            ) %>

            <.error :for={msg <- get_field_errors(f[:username_or_email], :username_or_email)}>
              <%= gettext("E-mail address") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label
              for="user_password"
              class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
            >
              <%= gettext("Password") %>
            </label>
          </div>
          <div phx-feedback-for={f[:password].name} class="mt-2">
            <%= password_input(f, :password,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 dark:bg-gray-700 dark:text-white ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                  unless(get_field_errors(f[:password], :password) == [],
                    do: "ring-red-600 focus:ring-red-600",
                    else: "ring-gray-300 focus:ring-indigo-600"
                  ),
              placeholder: gettext("Password"),
              value: f[:password].value,
              autocomplete: gettext("new password"),
              "phx-debounce": "blur"
            ) %>

            <.error :for={msg <- get_field_errors(f[:password], :password)}>
              <%= gettext("Password") <> " " <> msg %>
            </.error>
          </div>
        </div>

        <div class="w-[100%] flex justify-between items-center">
          <.link navigate={@sign_up_link}>
            <p class="block text-sm leading-6 text-blue-600 transition-all duration-500 ease-in-out hover:text-blue-500 dark:hover:text-blue-500 hover:cursor-pointer hover:underline">
              <%= gettext("Don't have an account? Sign up") %>
            </p>
          </.link>
          <.link navigate="/reset-password">
            <p class="block text-sm leading-6 text-blue-600 transition-all duration-500 ease-in-out hover:text-blue-500 dark:hover:text-blue-500 hover:cursor-pointer hover:underline">
              <%= gettext("Forgot Your Password?") %>
            </p>
          </.link>
        </div>

        <div>
          <%= submit(@cta,
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 "
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end

  defp get_link(route, params) do
    if params == %{} do
      route
    else
      "#{route}?#{URI.encode_query(params)}"
    end
  end
end
