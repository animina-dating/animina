defmodule AniminaWeb.UserLive.Login do
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

          <div :if={local_mail_adapter?()} class="alert alert-info mb-6">
            <.icon name="hero-information-circle" class="size-6 shrink-0" />
            <div>
              <p>Lokaler Mail-Adapter aktiv.</p>
              <p>
                E-Mails unter <.link href="/dev/mailbox" class="underline">/dev/mailbox</.link>
                einsehen.
              </p>
            </div>
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
              Anmelden und eingeloggt bleiben
            </.button>
            <.button class="btn btn-primary btn-soft w-full">
              Nur dieses Mal anmelden
            </.button>
          </.form>

          <div class="divider my-6">oder</div>

          <.form
            :let={f}
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
            class="space-y-4"
          >
            <.input
              readonly={!!@current_scope}
              field={f[:email]}
              type="email"
              label="E-Mail-Adresse"
              autocomplete="email"
              required
            />
            <.button class="btn btn-primary btn-soft w-full">
              Login-Link per E-Mail senden
            </.button>
          </.form>
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

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "Falls deine E-Mail-Adresse in unserem System ist, erhältst du in Kürze einen Login-Link."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:animina, Animina.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
