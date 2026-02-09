defmodule AniminaWeb.UserLive.PinConfirmation do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.FeatureFlags
  alias Animina.MailQueueChecker

  @max_attempts 3
  @dev_routes Application.compile_env(:animina, :dev_routes)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto">
        <div class="bg-surface rounded-xl shadow-md p-6 sm:p-8">
          <div class="text-center mb-6">
            <h1 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Confirm your email")}
            </h1>
            <p class="mt-2 text-base text-base-content/70 hyphens-none">
              {gettext("We sent a 6-digit code to")} <strong>{@email}</strong>.
            </p>
          </div>

          <div :if={@delivery_failure} role="alert" class="alert alert-warning mb-4">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-6 w-6 shrink-0 stroke-current"
              fill="none"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
            <div>
              <h3 class="font-bold">{gettext("Email delivery problem")}</h3>
              <p class="text-sm">
                {gettext(
                  "Your email provider is currently rejecting emails from our server. The confirmation code could not be delivered to %{email}.",
                  email: @email
                )}
              </p>
              <p class="text-sm mt-1">
                {gettext("Your account data will be automatically deleted in %{minutes} minutes.",
                  minutes: FeatureFlags.pin_validity_minutes()
                )}
              </p>
              <p class="text-sm mt-1">
                {gettext("Please try registering with a different email address, or try again later.")}
              </p>
            </div>
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
    case Phoenix.Token.verify(AniminaWeb.Endpoint, "pin_confirmation", token,
           max_age: FeatureFlags.pin_validity_minutes() * 60
         ) do
      {:ok, {:phantom, _id, email}} ->
        # Phantom flow: no real user behind this token.
        # Show identical UI to prevent email enumeration.
        {:ok,
         socket
         |> assign(
           phantom: true,
           email: email,
           delivery_failure: nil,
           remaining_attempts: @max_attempts,
           max_attempts: @max_attempts,
           remaining_minutes: FeatureFlags.pin_validity_minutes(),
           trigger_login: false,
           dev_routes: @dev_routes,
           login_form: to_form(%{"user_id" => "", "remember_me" => "true"}, as: "user")
         )
         |> assign_form()}

      {:ok, user_id} ->
        user = Accounts.get_user(user_id)

        if user && is_nil(user.confirmed_at) && user.confirmation_pin_hash do
          remaining_minutes = compute_remaining_minutes(user.confirmation_pin_sent_at)

          delivery_failure = check_delivery_failure(socket, user.email)

          {:ok,
           socket
           |> assign(
             phantom: false,
             user_id: user.id,
             email: user.email,
             delivery_failure: delivery_failure,
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

  @impl true
  def handle_info({:mail_delivery_failure, entry}, socket) do
    {:noreply, assign(socket, delivery_failure: entry)}
  end

  defp check_delivery_failure(socket, email) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Animina.PubSub, MailQueueChecker.topic(email))
      MailQueueChecker.lookup(String.downcase(email))
    else
      nil
    end
  end

  defp compute_remaining_minutes(nil), do: 0

  defp compute_remaining_minutes(sent_at) do
    elapsed = DateTime.diff(DateTime.utc_now(), sent_at, :minute)
    FeatureFlags.pin_validity_minutes() - elapsed
  end

  defp assign_form(socket) do
    assign(socket, form: to_form(%{"pin" => ""}, as: "pin"))
  end
end
