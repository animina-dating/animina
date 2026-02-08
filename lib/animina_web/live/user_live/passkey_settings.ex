defmodule AniminaWeb.UserLive.PasskeySettings do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.settings_header
          title={gettext("Passkeys")}
          subtitle={
            gettext(
              "Sign in with Face ID, Touch ID, or a security key — faster and more secure than passwords."
            )
          }
        />

        <%!-- Single hook element: handles browser support check + registration --%>
        <div id="passkey-register" phx-hook="PasskeyRegister" class="mb-8">
          <%!-- Browser support warning (shown/hidden by JS hook) --%>
          <div id="passkey-unsupported" class="hidden alert alert-warning mb-6">
            <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
            <span>{gettext("Your browser does not support passkeys.")}</span>
          </div>

          <%!-- Add passkey button (hidden by JS if unsupported) --%>
          <div id="passkey-add-btn">
            <.button
              phx-click="add_passkey"
              class="btn btn-primary"
              disabled={@registering}
            >
              <.icon name="hero-finger-print" class="h-5 w-5 mr-2" />
              {if @registering,
                do: gettext("Waiting for device..."),
                else: gettext("Add a passkey")}
            </.button>
          </div>
        </div>

        <%!-- Existing passkeys list --%>
        <div :if={@passkeys != []} class="space-y-3">
          <h2 class="text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3">
            {gettext("Your passkeys")}
          </h2>

          <div
            :for={passkey <- @passkeys}
            class="flex items-center gap-4 p-4 rounded-lg border border-base-300"
          >
            <span class="text-base-content/60">
              <.icon name="hero-key" class="h-6 w-6" />
            </span>
            <div class="flex-1 min-w-0">
              <div class="font-semibold text-sm text-base-content">
                {passkey.label || gettext("Passkey")}
              </div>
              <div class="text-xs text-base-content/60 mt-0.5">
                {gettext("Added %{date}", date: format_date(passkey.inserted_at))}
                <span :if={passkey.last_used_at}>
                  · {gettext("Last used %{date}", date: format_date(passkey.last_used_at))}
                </span>
              </div>
            </div>
            <button
              phx-click="delete_passkey"
              phx-value-id={passkey.id}
              data-confirm={gettext("Are you sure you want to remove this passkey?")}
              class="btn btn-ghost btn-sm text-error"
            >
              <.icon name="hero-trash" class="h-4 w-4" />
            </button>
          </div>
        </div>

        <div :if={@passkeys == []} class="text-center py-12 text-base-content/50">
          <.icon name="hero-finger-print" class="h-12 w-12 mx-auto mb-4 opacity-50" />
          <p class="text-sm">{gettext("No passkeys registered yet.")}</p>
          <p class="text-xs mt-1">
            {gettext("Add a passkey to sign in without a password.")}
          </p>
        </div>
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
      {:noreply, push_navigate(socket, to: ~p"/users/waitlist")}
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

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
