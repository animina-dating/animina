defmodule AniminaWeb.UserLive.AccountSuspended do
  @moduledoc """
  Shows suspension/ban info and allows filing an appeal.
  """

  use AniminaWeb, :live_view

  import Ecto.Query

  alias Animina.Repo
  alias Animina.Reports
  alias Animina.Reports.Report
  alias AniminaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Find the most recent resolved report against this user
    report = find_latest_report(user.id)
    appeal = if report, do: report.appeal

    {:ok,
     assign(socket,
       page_title: gettext("Account Suspended"),
       report: report,
       appeal: appeal,
       appeal_text: "",
       submitting: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto">
        <div class="text-center mb-8">
          <.icon name="hero-shield-exclamation" class="h-16 w-16 mx-auto text-error mb-4" />

          <h1 class="text-2xl font-bold mb-2">
            {if @current_scope.user.state == "banned",
              do: gettext("Account Permanently Banned"),
              else: gettext("Account Suspended")}
          </h1>

          <p
            :if={@current_scope.user.state == "suspended" && @current_scope.user.suspended_until}
            class="text-base-content/60"
          >
            {gettext("Your account is suspended until %{date}.",
              date: Calendar.strftime(@current_scope.user.suspended_until, "%Y-%m-%d %H:%M UTC")
            )}
          </p>

          <p :if={@current_scope.user.state == "banned"} class="text-base-content/60">
            {gettext("Your account has been permanently banned.")}
          </p>
        </div>

        <%!-- Appeal section --%>
        <div :if={@report && is_nil(@appeal)} class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title text-lg">{gettext("Submit an Appeal")}</h2>
            <p class="text-sm text-base-content/60 mb-3">
              {gettext("If you believe this decision was made in error, you may submit one appeal.")}
            </p>
            <form phx-submit="submit_appeal">
              <div class="form-control mb-3">
                <textarea
                  name="appeal_text"
                  class="textarea textarea-bordered w-full"
                  rows="4"
                  minlength="10"
                  maxlength="2000"
                  required
                  placeholder={
                    gettext("Explain why you believe this decision should be reconsidered...")
                  }
                  phx-change="update_appeal_text"
                >{@appeal_text}</textarea>
                <label class="label">
                  <span class="label-text-alt">{String.length(@appeal_text)}/2000</span>
                </label>
              </div>
              <button
                type="submit"
                class="btn btn-primary w-full"
                disabled={String.length(@appeal_text) < 10 || @submitting}
              >
                <span :if={@submitting} class="loading loading-spinner loading-sm"></span>
                {gettext("Submit Appeal")}
              </button>
            </form>
          </div>
        </div>

        <%!-- Appeal status --%>
        <div :if={@appeal} class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title text-lg">{gettext("Appeal Status")}</h2>
            <div class="flex items-center gap-2">
              <span :if={@appeal.status == "pending"} class="badge badge-warning">
                {gettext("Pending review")}
              </span>
              <span :if={@appeal.status == "approved"} class="badge badge-success">
                {gettext("Approved")}
              </span>
              <span :if={@appeal.status == "rejected"} class="badge badge-error">
                {gettext("Rejected")}
              </span>
            </div>
            <p :if={@appeal.resolution_notes} class="text-sm mt-2">
              {@appeal.resolution_notes}
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("update_appeal_text", %{"appeal_text" => text}, socket) do
    {:noreply, assign(socket, :appeal_text, String.slice(text, 0, 2000))}
  end

  def handle_event("submit_appeal", %{"appeal_text" => text}, socket) do
    report = socket.assigns.report
    user = socket.assigns.current_scope.user

    socket = assign(socket, :submitting, true)

    case Reports.create_appeal(report, user, text) do
      {:ok, appeal} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Appeal submitted. We will review it shortly."))
         |> assign(appeal: appeal, submitting: false)}

      {:error, :appeal_already_exists} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("An appeal has already been submitted for this report."))
         |> assign(submitting: false)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Could not submit appeal."))
         |> assign(submitting: false)}
    end
  end

  defp find_latest_report(user_id) do
    report =
      Report
      |> where([r], r.reported_user_id == ^user_id and r.status == "resolved")
      |> order_by([r], desc: r.resolved_at)
      |> limit(1)
      |> Repo.one()

    if report, do: Repo.preload(report, [:appeal]), else: nil
  end
end
