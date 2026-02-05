defmodule AniminaWeb.UserLive.ForgotPassword do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @dev_routes Application.compile_env(:animina, :dev_routes)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Forgot your password")}
            </h1>
            <p class="mt-2 text-base text-base-content/70">
              {gettext("Enter your email address and we will send you a password reset link.")}
            </p>
          </div>

          <.form
            :let={f}
            for={@form}
            id="forgot_password_form"
            phx-submit="send_reset_link"
            class="space-y-4"
          >
            <.input
              field={f[:email]}
              type="email"
              label={gettext("Email address")}
              autocomplete="email"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="btn btn-primary w-full">
              {gettext("Send reset link")}
            </.button>
          </.form>

          <%= if @sent do %>
            <div class="mt-4 p-4 bg-info/10 rounded-lg text-sm text-base-content/70">
              {gettext(
                "If an account exists with this email, you will receive password reset instructions shortly."
              )}
            </div>

            <p :if={@dev_routes} class="mt-4 text-center text-sm text-base-content/50">
              <a href="/dev/mailbox" target="_blank" class="underline hover:text-primary">
                {gettext("Open dev mailbox")}
              </a>
            </p>
          <% end %>

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
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{"email" => ""}, as: "user"),
       sent: false,
       dev_routes: @dev_routes
     )}
  end

  @impl true
  def handle_event("send_reset_link", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_password_reset_instructions(
        user,
        &url(~p"/users/reset-password/#{&1}")
      )
    end

    {:noreply, assign(socket, sent: true)}
  end
end
