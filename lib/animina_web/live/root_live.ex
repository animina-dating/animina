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
  def render(assigns) do
    ~H"""
    <div class="space-y-10 px-5">
      <.notification_box
        title={gettext("Animina Dating Plattform")}
        message={gettext("Fair, Fast and Free. Join us now!")}
        box_with_avatar={true}
        avatar_url="/images/unsplash/men/prince-akachi-4Yv84VgQkRM-unsplash.jpg"
        avatar_url_b="/images/unsplash/women/stefan-stefancik-QXevDflbl8A-unsplash.jpg"
      />

      <.form :let={f} for={@form} action={@action} method="POST" class="space-y-6">
        <div>
          <label for="username" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Username") %>
          </label>
          <div class="mt-2">
            <%= text_input(f, :username,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "Pusteblume1977",
              type: :text,
              required: true,
              autofocus: true,
              autocomplete: :username
            ) %>
          </div>
        </div>

        <%= text_input(f, :hidden_points, type: :hidden, value: 200) %>

        <div>
          <label for="name" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("Name") %>
          </label>
          <div class="mt-2">
            <%= text_input(f, :name,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: gettext("Alice"),
              type: :text,
              required: true,
              autocomplete: "given-name"
            ) %>
          </div>
        </div>

        <div>
          <label for="email" class="block text-sm font-medium leading-6 text-gray-900">
            <%= gettext("E-mail address") %>
          </label>
          <div class="mt-2">
            <%= text_input(f, :email,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: gettext("alice@example.net"),
              type: :email,
              required: true,
              autocomplete: :email
            ) %>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="password" class="block text-sm font-medium leading-6 text-gray-900">
              <%= gettext("Password") %>
              <span class="text-gray-400">(<%= gettext("at least 8 characters") %>)</span>
            </label>
          </div>
          <div class="mt-2">
            <%= password_input(f, :password,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: gettext("Password"),
              autocomplete: "new-password"
            ) %>
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
          <div class="mt-2">
            <%= date_input(f, :birthday,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "",
              value:
                [
                  (@today.year - 19) |> Integer.to_string() |> String.pad_leading(4, "0"),
                  @today.month |> Integer.to_string() |> String.pad_leading(2, "0"),
                  @today.day |> Integer.to_string() |> String.pad_leading(2, "0")
                ]
                |> Enum.join("-"),
              autocomplete: "bday"
            ) %>
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
          <div class="mt-2">
            <%= text_input(f, :zip_code,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              # Postal code of the Bundestag :-)
              placeholder: "11011",
              autocomplete: "postal-code"
            ) %>
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
          <div class="mt-2">
            <%= text_input(f, :height,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "160"
            ) %>
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
          <div class="mt-2">
            <%= text_input(f, :mobile_phone,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "0151-12345678"
            ) %>
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
end
