defmodule AniminaWeb.AccountEmailPasswordComponent do
  @moduledoc false
  use AniminaWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id="email-password-section">
      <h2 class="text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3">
        {gettext("Email & Password")}
      </h2>

      <div :if={@cooldown_active} class="alert alert-warning mb-4" role="alert">
        <.icon name="hero-shield-exclamation" class="h-5 w-5" />
        <p>
          {gettext(
            "For your security, a recent account change is pending review. We sent you an email to confirm or undo it. Until then, further email and password changes are paused for up to 48 hours to protect your account."
          )}
        </p>
      </div>

      <div :if={@pending_email} class="alert alert-info mb-4" role="alert">
        <p>
          {gettext(
            "Your current email is %{current_email}. A confirmation link has been sent to %{new_email}.",
            current_email: @current_email,
            new_email: @pending_email
          )}
        </p>
      </div>

      <fieldset disabled={@cooldown_active}>
        <.form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input
            field={@email_form[:email]}
            type="email"
            label={gettext("Email")}
            autocomplete="email"
            required
          />
          <.button variant="primary" phx-disable-with={gettext("Changing...")}>
            {gettext("Change Email")}
          </.button>
        </.form>
      </fieldset>

      <p :if={@dev_routes} class="mt-4 text-center text-sm text-base-content/50">
        <a href="/dev/mailbox" target="_blank" class="underline hover:text-primary">
          {gettext("Open dev mailbox")}
        </a>
      </p>

      <div class="divider" />

      <fieldset disabled={@cooldown_active}>
        <.form
          for={@password_form}
          id="password_form"
          action={~p"/my/settings/update-password"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            autocomplete="username"
            value={@current_email}
          />
          <.input
            field={@password_form[:password]}
            type="password"
            label={gettext("New password")}
            autocomplete="new-password"
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label={gettext("Confirm new password")}
            autocomplete="new-password"
          />
          <.button variant="primary" phx-disable-with={gettext("Saving...")}>
            {gettext("Save Password")}
          </.button>
        </.form>
      </fieldset>
    </div>
    """
  end
end
