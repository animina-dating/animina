defmodule AniminaWeb.UserLive.DeleteAccount do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/users/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>{gettext("Delete Account")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Delete Account")}
            <:subtitle>{gettext("This action cannot be easily undone")}</:subtitle>
          </.header>
        </div>

        <div class="alert alert-warning mb-6">
          <p>
            {gettext(
              "Your account will be marked for deletion. You have 30 days to log back in and contact support to recover it. After 30 days, all your data will be permanently deleted."
            )}
          </p>
        </div>

        <.form for={@form} id="delete_account_form" phx-submit="delete_account">
          <.input
            field={@form[:password]}
            type="password"
            label={gettext("Confirm your password")}
            required
            autocomplete="current-password"
          />
          <.button class={["btn", "btn-error"]} phx-disable-with={gettext("Deleting...")}>
            {gettext("Delete My Account")}
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"password" => ""}, as: "user")

    socket =
      socket
      |> assign(:page_title, gettext("Delete Account"))
      |> assign(:form, form)

    {:ok, socket}
  end

  @impl true
  def handle_event("delete_account", %{"user" => %{"password" => password}}, socket) do
    user = socket.assigns.current_scope.user

    if User.valid_password?(user, password) do
      {:ok, _user} = Accounts.soft_delete_user(user, originator: user)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Your account has been scheduled for deletion."))
       |> redirect(to: ~p"/")}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Invalid password."))
       |> assign(:form, to_form(%{"password" => ""}, as: "user"))}
    end
  end
end
