defmodule AniminaWeb.UserLive.LogsHub do
  @moduledoc """
  Logs hub LiveView showing available log viewers for the current user.
  """

  use AniminaWeb, :live_view

  alias Animina.Emails

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/my/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>{gettext("Logs")}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("Logs")}
            <:subtitle>{gettext("View your account activity logs")}</:subtitle>
          </.header>
        </div>

        <div class="grid gap-4">
          <.link
            navigate={~p"/my/logs/emails"}
            class="flex items-center gap-4 p-5 rounded-lg border border-base-300 hover:border-primary transition-colors"
          >
            <span class="flex-shrink-0 text-base-content/60">
              <.icon name="hero-envelope" class="h-8 w-8" />
            </span>
            <div class="flex-1 min-w-0">
              <div class="font-semibold text-base-content">{gettext("Email History")}</div>
              <div class="text-sm text-base-content/60 mt-0.5">
                {gettext("Log of all emails sent to your account")}
              </div>
            </div>
            <span class="badge badge-lg badge-outline font-mono">
              {@email_count}
            </span>
            <span class="flex-shrink-0 text-base-content/30">
              <.icon name="hero-chevron-right-mini" class="h-5 w-5" />
            </span>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_count = Emails.count_email_logs_for_user(user.id)

    {:ok,
     assign(socket,
       page_title: gettext("Logs"),
       email_count: email_count
     )}
  end
end
