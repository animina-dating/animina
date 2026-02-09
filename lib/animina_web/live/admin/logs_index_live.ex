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
        <div class="text-center mb-8">
          <.header>
            {gettext("Logs")}
            <:subtitle>{gettext("System log viewers")}</:subtitle>
          </.header>
        </div>

        <div class="grid gap-4">
          <.log_card
            navigate={~p"/admin/logs/activity"}
            title={gettext("Activity Logs")}
            description={gettext("Unified activity log for all system events")}
            count={@activity_count}
            icon="hero-clipboard-document-list"
          />

          <.log_card
            navigate={~p"/admin/logs/emails"}
            title={gettext("Email Logs")}
            description={gettext("Log of all emails sent by the system")}
            count={@email_count}
            icon="hero-envelope"
          />

          <.log_card
            navigate={~p"/admin/logs/ollama"}
            title={gettext("Ollama Logs")}
            description={gettext("Log of Ollama AI photo analysis runs")}
            count={@ollama_count}
            icon="hero-cpu-chip"
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :navigate, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :count, :integer, required: true
  attr :icon, :string, required: true

  defp log_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="flex items-center gap-4 p-5 rounded-lg border border-base-300 hover:border-primary transition-colors"
    >
      <span class="flex-shrink-0 text-base-content/60">
        <.icon name={@icon} class="h-8 w-8" />
      </span>
      <div class="flex-1 min-w-0">
        <div class="font-semibold text-base-content">{@title}</div>
        <div class="text-sm text-base-content/60 mt-0.5">{@description}</div>
      </div>
      <span class="badge badge-lg badge-outline font-mono">
        {@count}
      </span>
      <span class="flex-shrink-0 text-base-content/30">
        <.icon name="hero-chevron-right-mini" class="h-5 w-5" />
      </span>
    </.link>
    """
  end
end
