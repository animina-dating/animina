defmodule AniminaWeb.UserLive.AccountPasskeys do
  use AniminaWeb, :live_view

  on_mount {AniminaWeb.UserAuth, {:require_sudo_mode, "/my/settings/account/passkeys"}}

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/my/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>
              <.link navigate={~p"/my/settings/account"}>{gettext("Account & Security")}</.link>
            </li>
            <li>{gettext("Passkeys")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Passkeys")}
            <:subtitle>
              {gettext("Sign in with Face ID, Touch ID, or a security key")}
            </:subtitle>
          </.header>
        </div>

        <.live_component
          module={AniminaWeb.AccountPasskeysComponent}
          id="passkeys"
          user={@user}
          passkeys={@passkeys}
          registering={@registering}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    passkeys = Accounts.list_user_passkeys(user)

    socket =
      socket
      |> assign(:page_title, gettext("Passkeys"))
      |> assign(:user, user)
      |> assign(:passkeys, passkeys)
      |> assign(:registering, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("add_passkey", _params, socket) do
    socket =
      socket
      |> assign(:registering, true)
      |> push_event("passkey:register_begin", %{label: nil})

    {:noreply, socket}
  end

  def handle_event("passkey_registered", %{"id" => _id}, socket) do
    user = socket.assigns.current_scope.user
    passkeys = Accounts.list_user_passkeys(user)

    socket =
      socket
      |> assign(:passkeys, passkeys)
      |> assign(:registering, false)
      |> put_flash(:info, gettext("Passkey added successfully!"))

    if user.state == "waitlisted" do
      {:noreply, push_navigate(socket, to: ~p"/my/waitlist")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("passkey_register_error", %{"error" => "cancelled"}, socket) do
    {:noreply, assign(socket, :registering, false)}
  end

  def handle_event("passkey_register_error", %{"error" => error}, socket) do
    socket =
      socket
      |> assign(:registering, false)
      |> put_flash(:error, gettext("Could not add passkey: %{reason}", reason: error))

    {:noreply, socket}
  end

  def handle_event("delete_passkey", %{"id" => passkey_id}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.delete_user_passkey(user, passkey_id) do
      {:ok, _} ->
        passkeys = Accounts.list_user_passkeys(user)

        socket =
          socket
          |> assign(:passkeys, passkeys)
          |> put_flash(:info, gettext("Passkey removed."))

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not remove passkey."))}
    end
  end
end
