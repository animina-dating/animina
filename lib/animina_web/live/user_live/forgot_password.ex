defmodule AniminaWeb.UserLive.ForgotPassword do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md px-4 py-8">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              Passwort vergessen
            </h1>
            <p class="mt-2 text-base text-base-content/70">
              Gib deine E-Mail-Adresse ein und wir senden dir einen Link zum Zurücksetzen deines Passworts.
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
              label="E-Mail-Adresse"
              autocomplete="email"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="btn btn-primary w-full">
              Link zum Zurücksetzen senden
            </.button>
          </.form>

          <%= if @sent do %>
            <div class="mt-4 p-4 bg-info/10 rounded-lg text-sm text-base-content/70">
              Falls ein Konto mit dieser E-Mail-Adresse existiert, erhältst du in Kürze eine E-Mail mit Anweisungen zum Zurücksetzen deines Passworts.
            </div>
          <% end %>

          <div class="mt-6 text-center">
            <.link
              navigate={~p"/users/log-in"}
              class="text-sm font-semibold text-primary hover:underline"
            >
              Zurück zur Anmeldung
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"email" => ""}, as: "user"), sent: false)}
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
