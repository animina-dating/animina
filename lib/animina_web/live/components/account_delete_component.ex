defmodule AniminaWeb.AccountDeleteComponent do
  @moduledoc false
  use AniminaWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id="delete-account-section">
      <h2 class="text-xs font-semibold uppercase tracking-wider text-error/70 mb-3">
        {gettext("Delete Account")}
      </h2>

      <div class="alert alert-warning mb-6">
        <p>
          {gettext(
            "Your account will be marked for deletion. You have 30 days to log back in and contact support to recover it. After 30 days, all your data will be permanently deleted."
          )}
        </p>
      </div>

      <.form for={@delete_form} id="delete_account_form" phx-submit="delete_account">
        <.input
          field={@delete_form[:password]}
          id="delete_account_password"
          type="password"
          label={gettext("Confirm your password")}
          required
          autocomplete="current-password"
        />
        <.button class={["btn", "btn-error"]} phx-disable-with={gettext("Deleting...")}>
          {gettext("Delete My Account")}
        </.button>
      </.form>
    </div>
    """
  end
end
