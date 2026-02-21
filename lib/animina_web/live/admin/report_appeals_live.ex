defmodule AniminaWeb.Admin.ReportAppealsLive do
  @moduledoc """
  Admin/moderator view for reviewing report appeals.

  Enforces that the reviewer is different from the original report resolver.
  """

  use AniminaWeb, :live_view

  alias Animina.Reports
  alias Animina.Reports.Category
  alias Animina.Reports.Report
  alias AniminaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    appeals = Reports.list_pending_appeals(page: 1, per_page: 50)

    {:ok,
     assign(socket,
       page_title: gettext("Report Appeals"),
       appeals: appeals,
       selected_appeal: nil,
       resolution_notes: ""
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-6xl mx-auto">
        <.page_header
          title={gettext("Report Appeals")}
          subtitle={gettext("Review appeals from reported users")}
        >
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
          <:crumb navigate={~p"/admin/reports"}>{gettext("Reports")}</:crumb>
        </.page_header>

        <div :if={@selected_appeal} class="mb-6">
          <.appeal_detail
            appeal={@selected_appeal}
            current_user_id={@current_scope.user.id}
            resolution_notes={@resolution_notes}
          />
        </div>

        <div :if={@appeals.entries == []} class="text-center py-12 text-base-content/50">
          <.icon name="hero-shield-check" class="h-12 w-12 mx-auto mb-3 opacity-40" />
          <p class="text-lg">{gettext("No pending appeals")}</p>
        </div>

        <div :if={@appeals.entries != []} class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>{gettext("Appellant")}</th>
                <th>{gettext("Original Category")}</th>
                <th>{gettext("Original Resolution")}</th>
                <th>{gettext("Filed At")}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={appeal <- @appeals.entries} class="hover">
                <td>
                  <span :if={appeal.appellant}>{appeal.appellant.display_name}</span>
                  <span :if={!appeal.appellant} class="text-base-content/40 italic">
                    {gettext("Deleted user")}
                  </span>
                </td>
                <td>{Category.label(appeal.report.category)}</td>
                <td>{Report.resolution_label(appeal.report.resolution)}</td>
                <td class="text-sm text-base-content/60">
                  {Calendar.strftime(appeal.inserted_at, "%Y-%m-%d %H:%M")}
                </td>
                <td>
                  <button
                    phx-click="select_appeal"
                    phx-value-id={appeal.id}
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

  defp appeal_detail(assigns) do
    same_moderator = assigns.appeal.report.resolver_id == assigns.current_user_id

    assigns = assign(assigns, :same_moderator, same_moderator)

    ~H"""
    <div class="card bg-base-200 shadow-lg">
      <div class="card-body">
        <div class="flex justify-between items-start mb-4">
          <h2 class="card-title">{gettext("Appeal Details")}</h2>
          <button phx-click="deselect_appeal" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>

        <%!-- Original report info --%>
        <div class="mb-4">
          <h3 class="font-semibold mb-2">{gettext("Original Report")}</h3>
          <p><strong>{gettext("Category")}:</strong> {Category.label(@appeal.report.category)}</p>
          <p>
            <strong>{gettext("Resolution")}:</strong> {Report.resolution_label(
              @appeal.report.resolution
            )}
          </p>
          <p :if={@appeal.report.resolution_notes}>
            <strong>{gettext("Notes")}:</strong> {@appeal.report.resolution_notes}
          </p>
        </div>

        <%!-- Appeal text --%>
        <div class="mb-4">
          <h3 class="font-semibold mb-2">{gettext("Appeal Text")}</h3>
          <div class="bg-base-100 rounded-lg p-3 whitespace-pre-wrap">
            {@appeal.appeal_text}
          </div>
        </div>

        <%!-- Same moderator warning --%>
        <div :if={@same_moderator} class="alert alert-warning mb-4">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
          <span>
            {gettext("You resolved the original report. Another moderator must review this appeal.")}
          </span>
        </div>

        <%!-- Actions --%>
        <div :if={!@same_moderator} class="border-t border-base-300 pt-4">
          <form phx-change="update_notes" phx-submit="noop">
            <div class="form-control mb-3">
              <textarea
                class="textarea textarea-bordered w-full"
                rows="2"
                placeholder={gettext("Resolution notes...")}
                name="notes"
              >{@resolution_notes}</textarea>
            </div>
          </form>
          <div class="flex gap-2">
            <button
              phx-click="resolve_appeal"
              phx-value-decision="approved"
              class="btn btn-sm btn-success"
            >
              {gettext("Approve (restore user)")}
            </button>
            <button
              phx-click="resolve_appeal"
              phx-value-decision="rejected"
              class="btn btn-sm btn-error"
            >
              {gettext("Reject (uphold decision)")}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("select_appeal", %{"id" => id}, socket) do
    appeal = Reports.get_appeal!(id)
    {:noreply, assign(socket, selected_appeal: appeal, resolution_notes: "")}
  end

  def handle_event("deselect_appeal", _, socket) do
    {:noreply, assign(socket, selected_appeal: nil)}
  end

  def handle_event("update_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :resolution_notes, notes)}
  end

  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("resolve_appeal", %{"decision" => decision}, socket) do
    appeal = socket.assigns.selected_appeal
    reviewer = socket.assigns.current_scope.user
    notes = socket.assigns.resolution_notes

    case Reports.resolve_appeal(appeal, reviewer, decision, notes) do
      {:ok, _appeal} ->
        appeals = Reports.list_pending_appeals(page: 1, per_page: 50)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Appeal resolved."))
         |> assign(appeals: appeals, selected_appeal: nil)}

      {:error, :same_moderator} ->
        {:noreply,
         put_flash(socket, :error, gettext("Another moderator must review this appeal."))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end
end
