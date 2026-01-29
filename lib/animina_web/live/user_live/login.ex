defmodule AniminaWeb.UserLive.Login do
  use AniminaWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md px-4 py-8">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              Anmelden
            </h1>
            <p :if={!@current_scope} class="mt-2 text-base text-base-content/70">
              Noch kein Konto?
              <.link
                navigate={~p"/users/register"}
                class="font-semibold text-primary hover:underline"
              >
                Jetzt registrieren
              </.link>
            </p>
            <p :if={@current_scope} class="mt-2 text-base text-base-content/70">
              Bitte erneut authentifizieren, um sensible Aktionen durchzuführen.
            </p>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label="E-Mail-Adresse"
              autocomplete="email"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Passwort"
              autocomplete="current-password"
              required
            />
            <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
              Anmelden
            </.button>
          </.form>

          <div :if={!@current_scope} class="mt-4 text-center">
            <.link
              navigate={~p"/users/forgot-password"}
              class="text-sm text-base-content/70 hover:text-primary hover:underline"
            >
              Passwort vergessen?
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
