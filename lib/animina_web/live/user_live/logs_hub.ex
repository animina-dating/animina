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
        <.page_header title={gettext("Logs")} subtitle={gettext("View your account activity logs")}>
          <:crumb navigate={~p"/my"}>{gettext("My ANIMINA")}</:crumb>
        </.page_header>

        <div class="grid gap-4">
          <.hub_card
            navigate={~p"/my/logs/emails"}
            icon="hero-envelope"
            title={gettext("Email History")}
            subtitle={gettext("Log of all emails sent to your account")}
            icon_class="h-8 w-8"
            padding="p-5"
          >
            <:trailing>
              <span class="badge badge-lg badge-outline font-mono">{@email_count}</span>
            </:trailing>
          </.hub_card>
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
