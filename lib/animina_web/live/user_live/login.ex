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
              {gettext("Log in")}
            </h1>
            <p :if={!@current_scope} class="mt-2 text-base text-base-content/70">
              {gettext("Don't have an account?")}
              <.link
                navigate={~p"/users/register"}
                class="font-semibold text-primary hover:underline"
              >
                {gettext("Register now")}
              </.link>
            </p>
            <p :if={@current_scope} class="mt-2 text-base text-base-content/70">
              {gettext("Please re-authenticate to perform sensitive actions.")}
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
              label={gettext("Email address")}
              autocomplete="email"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password]}
              type="password"
              label={gettext("Password")}
              autocomplete="current-password"
              required
            />
            <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
              {gettext("Log in")}
            </.button>
          </.form>

          <div :if={!@current_scope} class="mt-4 text-center">
            <.link
              navigate={~p"/users/forgot-password"}
              class="text-sm text-base-content/70 hover:text-primary hover:underline"
            >
              {gettext("Forgot your password?")}
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
