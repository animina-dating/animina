defmodule AniminaWeb.UserLive.ResetPassword do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Set new password")}
            </h1>
          </div>

          <.form
            :let={f}
            for={@form}
            id="reset_password_form"
            phx-submit="reset_password"
            phx-change="validate"
            class="space-y-4"
          >
            <.input
              field={f[:password]}
              type="password"
              label={gettext("New password")}
              autocomplete="new-password"
              required
            />
            <.input
              field={f[:password_confirmation]}
              type="password"
              label={gettext("Confirm new password")}
              autocomplete="new-password"
              required
            />
            <.button class="btn btn-primary w-full">
              {gettext("Reset password")}
            </.button>
          </.form>

          <div class="mt-6 text-center">
            <.link
              navigate={~p"/users/log-in"}
              class="text-sm font-semibold text-primary hover:underline"
            >
              {gettext("Back to login")}
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_password_reset_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("Password reset link is invalid or expired.")
         )
         |> redirect(to: ~p"/users/log-in")}

      user ->
        form = Accounts.change_user_password(user) |> to_form(as: "user")

        {:ok,
         assign(socket,
           page_title: gettext("Reset Password"),
           user: user,
           form: form,
           token: token
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_password(socket.assigns.user, user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Password has been reset successfully."))
         |> redirect(to: ~p"/users/log-in")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
    end
  end
end
