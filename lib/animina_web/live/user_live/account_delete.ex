defmodule AniminaWeb.UserLive.AccountDelete do
  use AniminaWeb, :live_view

  on_mount {AniminaWeb.UserAuth, {:require_sudo_mode, "/my/settings/account/delete"}}

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/my"}>{gettext("My Hub")}</.link>
            </li>
            <li>
              <.link navigate={~p"/my/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>
              <.link navigate={~p"/my/settings/account"}>{gettext("Account & Security")}</.link>
            </li>
            <li>{gettext("Delete Account")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Delete Account")}
            <:subtitle>
              {gettext("Permanently delete your account and all your data")}
            </:subtitle>
          </.header>
        </div>

        <.live_component
          module={AniminaWeb.AccountDeleteComponent}
          id="delete-account"
          user={@user}
          delete_form={@delete_form}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:page_title, gettext("Delete Account"))
      |> assign(:user, user)
      |> assign(:delete_form, to_form(%{"password" => ""}, as: "delete"))

    {:ok, socket}
  end

  @impl true
  def handle_event("delete_account", %{"delete" => %{"password" => password}}, socket) do
    user = socket.assigns.current_scope.user

    if Accounts.User.valid_password?(user, password) do
      {:ok, _user} = Accounts.soft_delete_user(user, originator: user)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Your account has been scheduled for deletion."))
       |> redirect(to: ~p"/")}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Invalid password."))
       |> assign(:delete_form, to_form(%{"password" => ""}, as: "delete"))}
    end
  end
end
