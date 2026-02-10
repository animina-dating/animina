defmodule AniminaWeb.UserLive.AccountEmailPassword do
  use AniminaWeb, :live_view

  on_mount {AniminaWeb.UserAuth, {:require_sudo_mode, "/my/settings/account/email-password"}}

  alias Animina.Accounts
  alias Animina.Accounts.UserNotifier

  @dev_routes Application.compile_env(:animina, :dev_routes)

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
            <li>{gettext("Email & Password")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Email & Password")}
            <:subtitle>
              {gettext("Manage your email address and password")}
            </:subtitle>
          </.header>
        </div>

        <.live_component
          module={AniminaWeb.AccountEmailPasswordComponent}
          id="email-password"
          user={@user}
          current_email={@current_email}
          pending_email={@pending_email}
          cooldown_active={@cooldown_active}
          email_form={@email_form}
          password_form={@password_form}
          trigger_submit={@trigger_submit}
          dev_routes={@dev_routes}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token,
             originator: socket.assigns.current_scope.user
           ) do
        {:ok, {_user, security_info}} ->
          UserNotifier.deliver_email_changed_notification(
            socket.assigns.current_scope.user,
            security_info.old_email,
            socket.assigns.current_scope.user.email,
            url(~p"/users/security/undo/#{security_info.undo_token}"),
            url(~p"/users/security/confirm/#{security_info.confirm_token}")
          )

          put_flash(socket, :info, gettext("Email changed successfully."))

        {:error, :cooldown_active} ->
          put_flash(
            socket,
            :error,
            gettext("Cannot change email while a recent account change is being reviewed.")
          )

        {:error, _} ->
          put_flash(socket, :error, gettext("Email change link is invalid or it has expired."))
      end

    {:ok, push_navigate(socket, to: ~p"/my/settings/account/email-password")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:page_title, gettext("Email & Password"))
      |> assign(:user, user)
      |> assign(:current_email, user.email)
      |> assign(:pending_email, Accounts.get_pending_email_change(user))
      |> assign(:cooldown_active, Accounts.has_active_security_cooldown?(user.id))
      |> assign(:dev_routes, @dev_routes)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", %{"user" => user_params}, socket) do
    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", %{"user" => _user_params}, socket)
      when socket.assigns.cooldown_active do
    {:noreply,
     put_flash(
       socket,
       :error,
       gettext("Cannot change email while a recent account change is being reviewed.")
     )}
  end

  def handle_event("update_email", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        applied_user = Ecto.Changeset.apply_action!(changeset, :insert)

        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/my/settings/confirm-email/#{&1}")
        )

        info = gettext("A link to confirm your email change has been sent to the new address.")
        {:noreply, socket |> put_flash(:info, info) |> assign(:pending_email, applied_user.email)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", %{"user" => user_params}, socket) do
    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", %{"user" => _user_params}, socket)
      when socket.assigns.cooldown_active do
    {:noreply,
     put_flash(
       socket,
       :error,
       gettext("Cannot change password while a recent account change is being reviewed.")
     )}
  end

  def handle_event("update_password", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
