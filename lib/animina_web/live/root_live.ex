defmodule AniminaWeb.RootLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.User
  alias AshPhoenix.Form

  @impl true
  def mount(_params, session, socket) do
    current_user =
      case get_user_id_from_session(session) do
        nil ->
          nil

        "" ->
          nil

        user_id ->
          Accounts.User.by_id!(user_id)
      end

    socket =
      socket
      |> assign(current_user: current_user)
      |> assign(active_tab: :home)

    {:ok, socket}
  end

  defp get_user_id_from_session(session) do
    case session["user"] do
      nil ->
        nil

      "" ->
        nil

      user_id ->
        user_id
        |> String.split("=")
        |> List.last()
    end
  end

  @impl true
  @spec handle_params(
          any(),
          any(),
          atom()
          | %{
              :assigns =>
                atom() | %{:live_action => :register | :sign_in, optional(any()) => any()},
              optional(any()) => any()
            }
        ) :: {:noreply, map()}
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :register, _params) do
    socket
    |> assign(page_title: "animina - Die ehrliche Dating-App")
    |> assign(:form_id, "sign-up-form")
    |> assign(:cta, "Neu registrieren")
    |> assign(:alternative_path, ~p"/sign-in")
    |> assign(:alternative, "Have an account?")
    |> assign(:action, ~p"/auth/user/password/register")
    |> assign(
      :form,
      Form.for_create(User, :register_with_password, api: Accounts, as: "user")
    )
  end

  defp apply_action(socket, :sign_in, _params) do
    socket
    |> assign(:form_id, "sign-in-form")
    |> assign(:cta, "Sign in")
    |> assign(:alternative_path, ~p"/register")
    |> assign(:alternative, "Need an account?")
    |> assign(:action, ~p"/auth/user/password/sign_in")
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
        title="Willkommen bei Animina 🎉"
        message="der Open-Source-Dating-Plattform, die auch ohne Zwangs-Abo gut funktioniert!"
        box_with_avatar={false}
      />
      <.form :let={f} for={@form} action={@action} method="POST" class="space-y-6">
        <div>
          <label for="username" class="block text-sm font-medium leading-6 text-gray-900">
            Username <span class="text-gray-400">&ndash; öffentlich sichtbar</span>
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
            E-Mail-Adresse
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
              Passwort (mindestens 8 Zeichen)
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
