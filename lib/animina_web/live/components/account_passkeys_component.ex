defmodule AniminaWeb.AccountPasskeysComponent do
  @moduledoc false
  use AniminaWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div id="passkeys-section">
      <h2 class="text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3">
        {gettext("Passkeys")}
      </h2>

      <p class="text-sm text-base-content/60 mb-4">
        {gettext(
          "Sign in with Face ID, Touch ID, or a security key — faster and more secure than passwords."
        )}
      </p>

      <%!-- Single hook element: handles browser support check + registration --%>
      <div id="passkey-register" phx-hook="PasskeyRegister" class="mb-8">
        <%!-- Browser support warning (shown/hidden by JS hook) --%>
        <div id="passkey-unsupported" class="hidden alert alert-warning mb-6">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
          <span>{gettext("Your browser does not support passkeys.")}</span>
        </div>

        <%!-- Add passkey button (hidden by JS if unsupported) --%>
        <div id="passkey-add-btn">
          <.button
            phx-click="add_passkey"
            class="btn btn-primary"
            disabled={@registering}
          >
            <.icon name="hero-finger-print" class="h-5 w-5 mr-2" />
            {if @registering,
              do: gettext("Waiting for device..."),
              else: gettext("Add a passkey")}
          </.button>
        </div>
      </div>

      <%!-- Existing passkeys list --%>
      <div :if={@passkeys != []} class="space-y-3">
        <div
          :for={passkey <- @passkeys}
          class="flex items-center gap-4 p-4 rounded-lg border border-base-300"
        >
          <span class="text-base-content/60">
            <.icon name="hero-key" class="h-6 w-6" />
          </span>
          <div class="flex-1 min-w-0">
            <div class="font-semibold text-sm text-base-content">
              {passkey.label || gettext("Passkey")}
            </div>
            <div class="text-xs text-base-content/60 mt-0.5">
              {gettext("Added %{date}", date: format_date(passkey.inserted_at))}
              <span :if={passkey.last_used_at}>
                · {gettext("Last used %{date}", date: format_date(passkey.last_used_at))}
              </span>
            </div>
          </div>
          <button
            phx-click="delete_passkey"
            phx-value-id={passkey.id}
            data-confirm={gettext("Are you sure you want to remove this passkey?")}
            class="btn btn-ghost btn-sm text-error"
          >
            <.icon name="hero-trash" class="h-4 w-4" />
          </button>
        </div>
      </div>

      <div :if={@passkeys == []} class="text-center py-8 text-base-content/50">
        <.icon name="hero-finger-print" class="h-12 w-12 mx-auto mb-4 opacity-50" />
        <p class="text-sm">{gettext("No passkeys registered yet.")}</p>
        <p class="text-xs mt-1">
          {gettext("Add a passkey to sign in without a password.")}
        </p>
      </div>
    </div>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
