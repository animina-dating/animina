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
      |> assign(current_user: Registration.get_current_user(session))
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
    |> assign(page_title: "animina Dating-App")
    |> assign(:form_id, "sign-up-form")
    |> assign(:cta, "Neu registrieren")
    |> assign(:action, ~p"/auth/user/password/register")
    |> assign(
      :form,
      Form.for_create(BasicUser, :register_with_password, api: Accounts, as: "user")
    )
  end

  defp apply_action(socket, :sign_in, _params) do
    socket
    |> assign(:form_id, "sign-in-form")
    |> assign(:cta, "Sign in")
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
        title="Willkommen bei Animina 🎉"
        message="der Open-Source-Dating-Plattform, die auch ohne Zwangs-Abo gut funktioniert!"
        box_with_avatar={false}
      />

      <.form :let={f} for={@form} action={@action} method="POST" class="space-y-6">
        <div>
          <label for="username" class="block text-sm font-medium leading-6 text-gray-900">
            Username
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

        <div>
          <label for="name" class="block text-sm font-medium leading-6 text-gray-900">
            Name
          </label>
          <div class="mt-2">
            <%= text_input(f, :name,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "Horst",
              type: :text,
              required: true,
              autocomplete: "given-name"
            ) %>
          </div>
        </div>

        <div>
          <label for="email" class="block text-sm font-medium leading-6 text-gray-900">
            E-Mail-Adresse
          </label>
          <div class="mt-2">
            <%= text_input(f, :email,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "eddie@beispiel.de",
              type: :email,
              required: true,
              autocomplete: :email
            ) %>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="password" class="block text-sm font-medium leading-6 text-gray-900">
              Passwort <span class="text-gray-400">(mindestens 8 Zeichen)</span>
            </label>
          </div>
          <div class="mt-2">
            <%= password_input(f, :password,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "Passwort",
              autocomplete: "new-password"
            ) %>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="birthday" class="block text-sm font-medium leading-6 text-gray-900">
              Geburtstag
              <span class="text-gray-400">
                (heute mindestens 18 Jahre alt z.B. <%= "#{@today.day}.#{@today.month}.#{@today.year - 18}" %>)
              </span>
            </label>
          </div>
          <div class="mt-2">
            <%= date_input(f, :birthday,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "",
              autocomplete: "bday"
            ) %>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="gender" class="block text-sm font-medium leading-6 text-gray-900">
              Geschlecht
            </label>
          </div>
          <div class="mt-2">
            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, "male",
                id: "gender_male",
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500",
                checked: true
              ) %>
              <%= label(f, :gender, "Männlich",
                for: "gender_male",
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>

            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, "female",
                id: "gender_female",
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
              ) %>
              <%= label(f, :gender, "Weiblich",
                for: "gender_female",
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>

            <div class="flex items-center mb-4">
              <%= radio_button(f, :gender, "divers",
                id: "gender_divers",
                class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
              ) %>
              <%= label(f, :gender, "Divers",
                for: "gender_divers",
                class: "ml-3 block text-sm font-medium text-gray-700"
              ) %>
            </div>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="zip_code" class="block text-sm font-medium leading-6 text-gray-900">
              Postleitzahl
              <span class="text-gray-400">
                (5-stellige deutsche Postleitzahl)
              </span>
            </label>
          </div>
          <div class="mt-2">
            <%= text_input(f, :zip_code,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              # Zip code of Der Bundestag ;-)
              placeholder: "11011",
              autocomplete: "postal-code"
            ) %>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="height" class="block text-sm font-medium leading-6 text-gray-900">
              Körpergröße
              <span class="text-gray-400">
                (in cm)
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
              Handynummer
              <span class="text-gray-400">
                (für den Verifizierungscode)
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
