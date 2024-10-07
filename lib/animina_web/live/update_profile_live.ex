defmodule AniminaWeb.UpdateProfileLive do
  use AniminaWeb, :live_view
  alias Animina.Accounts
  alias Animina.Accounts.Points
  alias Animina.GenServers.ProfileViewCredits
  alias AshPhoenix.Form
  alias Phoenix.PubSub

  @impl true
  def mount(_params, %{"language" => language}, socket) do
    subscribe(socket)

    socket =
      socket
      |> assign(active_tab: :home)
      |> assign(
        :form,
        Form.for_update(socket.assigns.current_user, :update, domain: Accounts, as: "user")
        |> to_form()
      )
      |> assign(language: language)
      |> assign(
        page_title: "#{gettext("Update Profile For ")} #{socket.assigns.current_user.name}"
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => user}, socket) do
    form = Form.validate(socket.assigns.form, user, errors: true)

    {:noreply,
     socket
     |> assign(:form, form)}
  end

  def handle_event("submit", %{"user" => user}, socket) do
    form =
      Form.validate(socket.assigns.form, user)

    case Form.submit(form, params: user) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Profile updated successfully"))
         |> push_navigate(to: "/#{user.username}")}

      {:error, _} ->
        {:noreply, socket |> assign(:form, form)}
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      PubSub.subscribe(Animina.PubSub, "credits")
      PubSub.subscribe(Animina.PubSub, "messages")

      PubSub.subscribe(
        Animina.PubSub,
        "#{socket.assigns.current_user.id}"
      )
    end
  end

  def handle_info({:new_message, message}, socket) do
    unread_messages = socket.assigns.unread_messages ++ [message]

    {:noreply,
     socket
     |> assign(unread_messages: unread_messages)
     |> assign(number_of_unread_messages: Enum.count(unread_messages))}
  end

  def handle_info({:user, current_user}, socket) do
    if current_user.state in user_states_to_be_auto_logged_out() do
      {:noreply,
       socket
       |> push_navigate(to: "/auth/user/sign-out?auto_log_out=#{current_user.state}")}
    else
      {:noreply,
       socket
       |> assign(
         :form,
         Form.for_update(current_user, :update, domain: Accounts, as: "user")
         |> to_form()
       )
       |> assign(:current_user, current_user)}
    end
  end

  def handle_info({:display_updated_credits, credits}, socket) do
    current_user_credit_points =
      ProfileViewCredits.get_updated_credit_for_current_user(socket.assigns.current_user, credits)
      |> Points.humanized_points()

    {:noreply,
     socket
     |> assign(current_user_credit_points: current_user_credit_points)}
  end

  @impl true
  def handle_info({:credit_updated, _updated_credit}, socket) do
    {:noreply, socket}
  end

  defp user_states_to_be_auto_logged_out do
    [
      :under_investigation,
      :banned,
      :archived
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-3">
      <h1 class="text-4xl dark:text-white font-semibold">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Update Your Profile") %>
        <% end) %>
      </h1>

      <.form
        :let={f}
        for={@form}
        id="basic_user_update_form"
        class="space-y-6 group "
        phx-change="validate"
        phx-submit="submit"
      >
        <div class="w-[100%] md:grid grid-cols-2 gap-8">
          <div>
            <label
              for="user_username"
              class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Username") %>
              <% end) %>
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
                placeholder: with_locale(@language, fn -> gettext("Pusteblume1977") end),
                value: f[:username].value,
                type: :text,
                required: true,
                autocomplete: :username,
                "phx-debounce": "200"
              ) %>

              <.error :for={msg <- get_field_errors(f[:username], :username)}>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Username") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>

          <%= text_input(f, :language, type: :hidden, value: @language) %>

          <div>
            <label
              for="user_name"
              class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Name") %>
              <% end) %>
            </label>
            <div phx-feedback-for={f[:name].name} class="mt-2">
              <%= text_input(f, :name,
                class:
                  "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:name], :name) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                placeholder: with_locale(@language, fn -> gettext("Alice") end),
                value: f[:name].value,
                type: :text,
                required: true,
                autocomplete: "given-name"
              ) %>

              <.error :for={msg <- get_field_errors(f[:name], :name)}>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Name") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label
              for="user_birthday"
              class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Date of birth") %>
              <% end) %>
            </label>
          </div>
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
              <%= with_locale(@language, fn -> %>
                <%= gettext("Date of birth") <> " " <> msg %>
              <% end) %>
            </.error>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label
              for="user_gender"
              class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Gender") %>
              <% end) %>
            </label>
          </div>
          <div class="mt-2" phx-no-format>

          <%
            item_code = "male"
            item_title = with_locale(@language, fn -> gettext("Male") end)
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
            item_title = with_locale(@language, fn -> gettext("Female") end)
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
            item_title = with_locale(@language, fn -> gettext("Diverse") end)
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
              class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
            >
              <%= with_locale(@language, fn -> %>
                <%= gettext("Occupation") %>
              <% end) %>
            </label>
            <div phx-feedback-for={f[:occupation].name} class="mt-2">
              <%= text_input(f, :occupation,
                class:
                  "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
                    unless(get_field_errors(f[:occupation], :name) == [],
                      do: "ring-red-600 focus:ring-red-600",
                      else: "ring-gray-300 focus:ring-indigo-600"
                    ),
                placeholder: with_locale(@language, fn -> gettext("Dating Coach") end),
                value: f[:occupation].value,
                type: :text,
                required: false,
                autocomplete: "organization-title"
              ) %>

              <.error :for={msg <- get_field_errors(f[:occupation], :name)}>
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Occupation") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>

          <div>
            <div class="flex items-center justify-between">
              <label
                for="user_zip_code"
                class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
              >
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Zip code") %>
                <% end) %>
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
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Zip code") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>

          <div>
            <div class="flex items-center justify-between">
              <label
                for="user_height"
                class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
              >
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Height") %>
                <% end) %>
                <span class="text-gray-400 dark:text-gray-100">
                  <%= with_locale(@language, fn -> %>
                    (<%= gettext("in cm") %>)
                  <% end) %>
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
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Height") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>

          <div>
            <div class="flex items-center justify-between">
              <label
                for="user_mobile_phone"
                class="block text-sm font-medium leading-6 dark:text-white text-gray-900"
              >
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Mobile phone number") %>
                <% end) %>
                <span class="text-gray-400 dark:text-gray-100"></span>
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
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Mobile phone number") <> " " <> msg %>
                <% end) %>
              </.error>
            </div>
          </div>
        </div>

        <div>
          <%= submit(with_locale(@language, fn -> gettext("Save Profile Details") end),
            class:
              "flex w-full justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@form.errors != [],
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.errors != []
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
