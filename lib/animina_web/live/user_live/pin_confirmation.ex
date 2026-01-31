defmodule AniminaWeb.UserLive.PinConfirmation do
  use AniminaWeb, :live_view

  alias Animina.Accounts

  @max_attempts 3
  @dev_routes Application.compile_env(:animina, :dev_routes)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md px-4 py-8">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-6">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Confirm your email")}
            </h1>
            <p class="mt-2 text-base text-base-content/70 hyphens-none">
              {gettext("We sent a 6-digit code to")} <strong>{@email}</strong>.
            </p>
          </div>

          <.form
            for={@form}
            id="pin_form"
            phx-submit="verify_pin"
            class="space-y-6"
          >
            <div>
              <.input
                field={@form[:pin]}
                type="text"
                label={gettext("Confirmation code")}
                inputmode="numeric"
                pattern="[0-9]{6}"
                maxlength="6"
                autocomplete="one-time-code"
                placeholder="000000"
                required
                phx-mounted={JS.focus_first()}
              />
            </div>

            <div class="text-sm text-base-content/60 space-y-1">
              <p>
                {gettext("Remaining attempts:")}
                <strong>{@remaining_attempts}</strong> {gettext("of")} {@max_attempts}
              </p>
              <p>
                {gettext("Remaining time:")}
                <strong>{@remaining_minutes}</strong> {gettext("minutes")}
              </p>
            </div>

            <.button
              phx-disable-with={gettext("Verifying...")}
              class="btn btn-primary w-full"
            >
              {gettext("Confirm")}
            </.button>
          </.form>

          <p :if={@dev_routes} class="mt-4 text-center text-sm text-base-content/50">
            <a href="/dev/mailbox" target="_blank" class="underline hover:text-primary">
              {gettext("Open dev mailbox")}
            </a>
          </p>
        </div>
      </div>

      <.form
        :if={@trigger_login}
        for={@login_form}
        id="pin_login_form"
        action={~p"/users/log-in/pin-confirmed"}
        phx-trigger-action={@trigger_login}
      >
        <input type="hidden" name={@login_form[:user_id].name} value={@login_form[:user_id].value} />
        <input
          type="hidden"
          name={@login_form[:remember_me].name}
          value={@login_form[:remember_me].value}
        />
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Phoenix.Token.verify(AniminaWeb.Endpoint, "pin_confirmation", token, max_age: 1800) do
      {:ok, {:phantom, _id, email}} ->
        # Phantom flow: no real user behind this token.
        # Show identical UI to prevent email enumeration.
        {:ok,
         socket
         |> assign(
           phantom: true,
           email: email,
           remaining_attempts: @max_attempts,
           max_attempts: @max_attempts,
           remaining_minutes: 30,
           trigger_login: false,
           dev_routes: @dev_routes,
           login_form: to_form(%{"user_id" => "", "remember_me" => "true"}, as: "user")
         )
         |> assign_form()}

      {:ok, user_id} ->
        user = Accounts.get_user(user_id)

        if user && is_nil(user.confirmed_at) && user.confirmation_pin_hash do
          remaining_minutes = compute_remaining_minutes(user.confirmation_pin_sent_at)

          {:ok,
           socket
           |> assign(
             phantom: false,
             user_id: user.id,
             email: user.email,
             remaining_attempts: @max_attempts - user.confirmation_pin_attempts,
             max_attempts: @max_attempts,
             remaining_minutes: max(0, remaining_minutes),
             trigger_login: false,
             dev_routes: @dev_routes,
             login_form: to_form(%{"user_id" => user.id, "remember_me" => "true"}, as: "user")
           )
           |> assign_form()}
        else
          {:ok,
           socket
           |> put_flash(:error, gettext("This confirmation link is invalid or expired."))
           |> push_navigate(to: ~p"/users/register")}
        end

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This confirmation link is invalid or expired."))
         |> push_navigate(to: ~p"/users/register")}
    end
  end

  @impl true
  def handle_event(
        "verify_pin",
        %{"pin" => %{"pin" => _pin}},
        %{assigns: %{phantom: true}} = socket
      ) do
    remaining = socket.assigns.remaining_attempts - 1

    if remaining <= 0 do
      {:noreply,
       socket
       |> put_flash(
         :error,
         gettext("Your account has been deleted. Please register again.")
       )
       |> push_navigate(to: ~p"/users/register")}
    else
      {:noreply,
       socket
       |> assign(remaining_attempts: remaining)
       |> put_flash(
         :error,
         ngettext(
           "Wrong code. %{count} attempt remaining.",
           "Wrong code. %{count} attempts remaining.",
           remaining
         )
       )
       |> assign_form()}
    end
  end

  def handle_event("verify_pin", %{"pin" => %{"pin" => pin}}, socket) do
    user = Accounts.get_user(socket.assigns.user_id)

    case Accounts.verify_confirmation_pin(user, String.trim(pin)) do
      {:ok, _user} ->
        {:noreply, assign(socket, trigger_login: true)}

      {:error, :wrong_pin} ->
        remaining = socket.assigns.remaining_attempts - 1

        {:noreply,
         socket
         |> assign(remaining_attempts: remaining)
         |> put_flash(
           :error,
           ngettext(
             "Wrong code. %{count} attempt remaining.",
             "Wrong code. %{count} attempts remaining.",
             remaining
           )
         )
         |> assign_form()}

      {:error, reason} when reason in [:too_many_attempts, :expired, :not_found] ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Your account has been deleted. Please register again.")
         )
         |> push_navigate(to: ~p"/users/register")}
    end
  end

  defp compute_remaining_minutes(nil), do: 0

  defp compute_remaining_minutes(sent_at) do
    elapsed = DateTime.diff(DateTime.utc_now(), sent_at, :minute)
    30 - elapsed
  end

  defp assign_form(socket) do
    assign(socket, form: to_form(%{"pin" => ""}, as: "pin"))
  end
end
