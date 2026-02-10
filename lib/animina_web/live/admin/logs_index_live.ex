defmodule AniminaWeb.Admin.LogsIndexLive do
  use AniminaWeb, :live_view

  alias Animina.ActivityLog
  alias Animina.Emails
  alias Animina.Photos
  alias AniminaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    email_count = Emails.list_email_logs(per_page: 1).total_count
    ollama_count = Photos.list_ollama_logs(per_page: 1).total_count
    activity_count = ActivityLog.count()

    {:ok,
     assign(socket,
       page_title: gettext("Logs"),
       email_count: email_count,
       ollama_count: ollama_count,
       activity_count: activity_count
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <.page_header title={gettext("Logs")} subtitle={gettext("System log viewers")}>
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
        </.page_header>

        <div class="grid gap-4">
          <.hub_card
            navigate={~p"/admin/logs/activity"}
            title={gettext("Activity Logs")}
            subtitle={gettext("Unified activity log for all system events")}
            icon="hero-clipboard-document-list"
            icon_class="h-8 w-8"
            padding="p-5"
          >
            <:trailing>
              <span class="badge badge-lg badge-outline font-mono">{@activity_count}</span>
            </:trailing>
          </.hub_card>

          <.hub_card
            navigate={~p"/admin/logs/emails"}
            title={gettext("Email Logs")}
            subtitle={gettext("Log of all emails sent by the system")}
            icon="hero-envelope"
            icon_class="h-8 w-8"
            padding="p-5"
          >
            <:trailing>
              <span class="badge badge-lg badge-outline font-mono">{@email_count}</span>
            </:trailing>
          </.hub_card>

          <.hub_card
            navigate={~p"/admin/logs/ollama"}
            title={gettext("Ollama Logs")}
            subtitle={gettext("Log of Ollama AI photo analysis runs")}
            icon="hero-cpu-chip"
            icon_class="h-8 w-8"
            padding="p-5"
          >
            <:trailing>
              <span class="badge badge-lg badge-outline font-mono">{@ollama_count}</span>
            </:trailing>
          </.hub_card>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
