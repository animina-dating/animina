defmodule AniminaWeb.Admin.ReportsLive do
  @moduledoc """
  Admin/moderator view for reviewing user reports.

  Shows a priority-ordered queue of pending reports with evidence,
  strike history, and resolution actions.
  """

  use AniminaWeb, :live_view

  alias Animina.Reports
  alias Animina.Reports.Category
  alias Animina.Reports.Report
  alias AniminaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    reports = Reports.list_pending_reports(page: 1, per_page: 50)

    {:ok,
     assign(socket,
       page_title: gettext("User Reports"),
       reports: reports,
       selected_report: nil,
       strike_history: [],
       recommended_action: nil,
       reporter_stats: nil,
       resolution_notes: ""
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-6xl mx-auto">
        <div class="mb-6">
          <.header>
            {gettext("User Reports")}
            <:subtitle>{gettext("Review and resolve user reports")}</:subtitle>
          </.header>
        </div>

        <div :if={@selected_report} class="mb-6">
          <.report_detail
            report={@selected_report}
            strike_history={@strike_history}
            recommended_action={@recommended_action}
            reporter_stats={@reporter_stats}
            resolution_notes={@resolution_notes}
          />
        </div>

        <div :if={@reports.entries == []} class="text-center py-12 text-base-content/50">
          <.icon name="hero-shield-check" class="h-12 w-12 mx-auto mb-3 opacity-40" />
          <p class="text-lg">{gettext("No pending reports")}</p>
        </div>

        <div :if={@reports.entries != []} class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>{gettext("Priority")}</th>
                <th>{gettext("Category")}</th>
                <th>{gettext("Reported User")}</th>
                <th>{gettext("Reporter")}</th>
                <th>{gettext("Context")}</th>
                <th>{gettext("Reported At")}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={report <- @reports.entries} class="hover">
                <td><.priority_badge priority={report.priority} /></td>
                <td>{Category.label(report.category)}</td>
                <td>
                  <span :if={report.reported_user}>
                    {report.reported_user.display_name}
                  </span>
                  <span :if={!report.reported_user} class="text-base-content/40 italic">
                    {gettext("Deleted user")}
                  </span>
                </td>
                <td>
                  <span :if={report.reporter}>
                    {report.reporter.display_name}
                  </span>
                  <span :if={!report.reporter} class="text-base-content/40 italic">
                    {gettext("System")}
                  </span>
                </td>
                <td>
                  <span class="badge badge-outline badge-sm">{report.context_type}</span>
                </td>
                <td class="text-sm text-base-content/60">
                  {Calendar.strftime(report.inserted_at, "%Y-%m-%d %H:%M")}
                </td>
                <td>
                  <button
                    phx-click="select_report"
                    phx-value-id={report.id}
                    class="btn btn-sm btn-primary"
                  >
                    {gettext("Review")}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp report_detail(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
        <div class="flex justify-between items-start mb-4">
          <h2 class="card-title">
            {gettext("Report Details")}
          </h2>
          <button phx-click="deselect_report" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>

        <%!-- Report info --%>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div>
            <p class="text-sm font-medium text-base-content/60">{gettext("Category")}</p>
            <p class="font-semibold">
              <.priority_badge priority={@report.priority} /> {Category.label(@report.category)}
            </p>
          </div>
          <div>
            <p class="text-sm font-medium text-base-content/60">{gettext("Context")}</p>
            <p>{@report.context_type}</p>
          </div>
          <div :if={@report.description}>
            <p class="text-sm font-medium text-base-content/60">{gettext("Description")}</p>
            <p class="whitespace-pre-wrap">{@report.description}</p>
          </div>
        </div>

        <%!-- Strike history --%>
        <div class="mb-6">
          <h3 class="font-semibold mb-2">
            {gettext("Strike History")}
            <span class="badge badge-warning ml-2">
              {length(@strike_history)} {gettext("prior strike(s)")}
            </span>
          </h3>
          <div :if={@strike_history == []} class="text-sm text-base-content/50">
            {gettext("No prior strikes")}
          </div>
          <div :for={strike <- @strike_history} class="text-sm border-l-2 border-warning pl-3 mb-2">
            <span class="font-medium">{strike.resolution}</span>
            — {Category.label(strike.category)}
            <span class="text-base-content/50">
              ({Calendar.strftime(strike.resolved_at, "%Y-%m-%d")})
            </span>
          </div>
        </div>

        <%!-- Recommended action --%>
        <div :if={@recommended_action} class="alert alert-info mb-6">
          <.icon name="hero-light-bulb" class="h-5 w-5" />
          <span>
            {gettext("Recommended action:")}
            <strong>{Report.resolution_label(@recommended_action)}</strong>
          </span>
        </div>

        <%!-- Reporter credibility --%>
        <div :if={@reporter_stats} class="mb-6">
          <h3 class="font-semibold mb-1">{gettext("Reporter Credibility")}</h3>
          <p class="text-sm">
            {@reporter_stats.total} {gettext("reports filed")}, {@reporter_stats.upheld_pct}% {gettext(
              "upheld"
            )}
          </p>
        </div>

        <%!-- Evidence --%>
        <div :if={@report.evidence} class="mb-6">
          <h3 class="font-semibold mb-2">{gettext("Evidence")}</h3>

          <div :if={@report.evidence.conversation_snapshot} class="mb-4">
            <p class="text-sm font-medium text-base-content/60 mb-1">{gettext("Conversation")}</p>
            <div class="bg-base-100 rounded-lg p-3 max-h-64 overflow-y-auto text-sm">
              <div :for={msg <- @report.evidence.conversation_snapshot["messages"] || []} class="mb-2">
                <span class="font-medium text-xs text-base-content/60">
                  {msg["sender_id"] |> String.slice(0, 8)}...
                </span>
                <p>{msg["content"]}</p>
              </div>
            </div>
          </div>

          <div :if={@report.evidence.profile_snapshot} class="mb-4">
            <p class="text-sm font-medium text-base-content/60 mb-1">{gettext("Profile Snapshot")}</p>
            <div class="bg-base-100 rounded-lg p-3 text-sm">
              <p>
                <strong>{gettext("Name")}:</strong> {@report.evidence.profile_snapshot["display_name"]}
              </p>
              <p :if={@report.evidence.profile_snapshot["occupation"]}>
                <strong>{gettext("Occupation")}:</strong> {@report.evidence.profile_snapshot[
                  "occupation"
                ]}
              </p>
            </div>
          </div>
        </div>

        <%!-- Resolution actions --%>
        <div class="border-t border-base-300 pt-4">
          <h3 class="font-semibold mb-3">{gettext("Resolve")}</h3>
          <form phx-change="update_notes" phx-submit="noop">
            <div class="form-control mb-3">
              <textarea
                class="textarea textarea-bordered w-full"
                rows="2"
                placeholder={gettext("Resolution notes (required)...")}
                name="notes"
              >{@resolution_notes}</textarea>
            </div>
          </form>
          <div class="flex flex-wrap gap-2">
            <button
              phx-click="resolve"
              phx-value-resolution="dismissed"
              class="btn btn-sm btn-outline"
              disabled={@resolution_notes == ""}
            >
              {gettext("Dismiss")}
            </button>
            <button
              phx-click="resolve"
              phx-value-resolution="warning"
              class="btn btn-sm btn-warning"
              disabled={@resolution_notes == ""}
            >
              {gettext("Warn")}
            </button>
            <button
              phx-click="resolve"
              phx-value-resolution="temp_ban_3"
              class="btn btn-sm btn-secondary"
              disabled={@resolution_notes == ""}
            >
              {gettext("3-day ban")}
            </button>
            <button
              phx-click="resolve"
              phx-value-resolution="temp_ban_7"
              class="btn btn-sm btn-secondary"
              disabled={@resolution_notes == ""}
            >
              {gettext("7-day ban")}
            </button>
            <button
              phx-click="resolve"
              phx-value-resolution="temp_ban_30"
              class="btn btn-sm btn-secondary"
              disabled={@resolution_notes == ""}
            >
              {gettext("30-day ban")}
            </button>
            <button
              phx-click="resolve"
              phx-value-resolution="permanent_ban"
              class="btn btn-sm btn-error"
              disabled={@resolution_notes == ""}
            >
              {gettext("Permanent ban")}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp priority_badge(assigns) do
    class =
      case assigns.priority do
        "critical" -> "badge badge-error badge-sm"
        "high" -> "badge badge-warning badge-sm"
        "medium" -> "badge badge-info badge-sm"
        _ -> "badge badge-ghost badge-sm"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={@class}>{@priority}</span>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("select_report", %{"id" => id}, socket) do
    report = Reports.get_report!(id)

    strike_history =
      if report.reported_user, do: Reports.strike_history(report.reported_user), else: []

    recommended_action =
      if report.reported_user, do: Reports.recommended_action(report.reported_user), else: nil

    reporter_stats =
      if report.reporter_id, do: Reports.reporter_stats(report.reporter_id), else: nil

    {:noreply,
     assign(socket,
       selected_report: report,
       strike_history: strike_history,
       recommended_action: recommended_action,
       reporter_stats: reporter_stats,
       resolution_notes: ""
     )}
  end

  def handle_event("deselect_report", _, socket) do
    {:noreply, assign(socket, selected_report: nil)}
  end

  def handle_event("update_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :resolution_notes, notes)}
  end

  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("resolve", %{"resolution" => resolution}, socket) do
    report = socket.assigns.selected_report
    moderator = socket.assigns.current_scope.user
    notes = socket.assigns.resolution_notes

    case Reports.resolve_report(report, moderator, resolution, notes) do
      {:ok, _report} ->
        reports = Reports.list_pending_reports(page: 1, per_page: 50)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Report resolved."))
         |> assign(reports: reports, selected_report: nil)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end
end
