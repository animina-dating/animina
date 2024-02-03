defmodule AniminaWeb.PotentialPartnerLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.User
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

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(page_title: "animina Profil vervollständigen")
    |> assign(:form_id, "sign-up-form")
    |> assign(:cta, "Speichern")
    |> assign(:alternative_path, ~p"/sign-in")
    |> assign(:alternative, "Have an account?")
    |> assign(:action, ~p"/auth/user/password/register")
    |> assign(
      :form,
      Form.for_action(User, :sign_in_with_password, api: Accounts, as: "user")
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 px-5">
      <.notification_box
        title={"Hallo #{@current_user.name}!"}
        message="Danke für Deine Registierung."
      />

      <.form :let={f} for={@form} action={@action} method="POST" class="space-y-6">
        <div>
          <label for="username" class="block text-sm font-medium leading-6 text-gray-900">
            Username <span class="text-gray-400">- öffentlich sichtbar</span>
          </label>
          <div class="mt-2">
            <%= text_input(f, :username,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "Pusteblume1977",
              type: :text,
              required: true,
              autofocus: true
            ) %>
          </div>
        </div>

        <div>
          <label for="email" class="block text-sm font-medium leading-6 text-gray-900">
            E-Mail Addresse
          </label>
          <div class="mt-2">
            <%= text_input(f, :email,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: "eddie@beispiel.de",
              type: :email,
              required: true
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
              placeholder: "Passwort"
            ) %>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between">
            <label for="birthday" class="block text-sm font-medium leading-6 text-gray-900">
              Geburtstag
            </label>
          </div>
          <div class="mt-2">
            <%= date_input(f, :birthday,
              class:
                "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
              placeholder: ""
            ) %>
          </div>
        </div>

        <div>
          <label class="text-base font-semibold text-gray-900">Geschlecht</label>
          <fieldset class="mt-4">
            <legend class="sr-only">Geschlecht</legend>
            <div class="space-y-4">
              <div class="flex items-center">
                <%= radio_button(f, :gender, "male",
                  class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-600",
                  checked: true
                ) %>

                <label for="male" class="ml-3 block text-sm font-medium leading-6 text-gray-900">
                  Männlich
                </label>
              </div>

              <div class="flex items-center">
                <%= radio_button(f, :gender, "female",
                  class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-600"
                ) %>

                <label for="female" class="ml-3 block text-sm font-medium leading-6 text-gray-900">
                  Weiblich
                </label>
              </div>

              <div class="flex items-center">
                <%= radio_button(f, :gender, "diverse",
                  class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-600"
                ) %>

                <label for="diverse" class="ml-3 block text-sm font-medium leading-6 text-gray-900">
                  Divers
                </label>
              </div>
            </div>
          </fieldset>
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
              placeholder: "12345"
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
