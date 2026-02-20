defmodule AniminaWeb.Admin.AnalyticsEngagementLive do
  use AniminaWeb, :live_view

  alias Animina.Analytics
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_days: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Analytics — Engagement"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    days = parse_days(params["days"])

    active_users = Analytics.active_user_counts()
    stickiness = Analytics.dau_mau_ratio(active_users)
    dau_trend = Analytics.dau_series(days)
    engagement = Analytics.feature_engagement(days)

    {:noreply,
     assign(socket,
       days: days,
       dau: active_users.dau,
       wau: active_users.wau,
       mau: active_users.mau,
       stickiness: stickiness,
       dau_trend: dau_trend,
       engagement: engagement,
       max_dau: max_dau(dau_trend)
     )}
  end

  defp max_dau([]), do: 1
  defp max_dau(trend), do: max(Enum.max_by(trend, & &1.count).count, 1)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto">
        <div class="mb-6">
          <.link navigate={~p"/admin/analytics"} class="text-sm text-base-content/60 hover:text-base-content">
            &larr; {gettext("Analytics")}
          </.link>
        </div>

        <.header>
          {gettext("Engagement")}
          <:subtitle>{gettext("User activity and feature usage")}</:subtitle>
        </.header>

        <%!-- Date range selector --%>
        <div class="flex gap-2 mt-4 mb-6">
          <.link
            :for={d <- [7, 30, 90]}
            patch={~p"/admin/analytics/engagement?#{%{days: d}}"}
            class={"btn btn-sm #{if @days == d, do: "btn-primary", else: "btn-ghost"}"}
          >
            {ngettext("%{count} day", "%{count} days", d)}
          </.link>
        </div>

        <%!-- Active user stats --%>
        <div class="stats stats-vertical sm:stats-horizontal shadow w-full mb-8">
          <div class="stat">
            <div class="stat-title">{gettext("DAU")}</div>
            <div class="stat-value">{@dau}</div>
            <div class="stat-desc">{gettext("Last 24 hours")}</div>
          </div>
          <div class="stat">
            <div class="stat-title">{gettext("WAU")}</div>
            <div class="stat-value">{@wau}</div>
            <div class="stat-desc">{gettext("Last 7 days")}</div>
          </div>
          <div class="stat">
            <div class="stat-title">{gettext("MAU")}</div>
            <div class="stat-value">{@mau}</div>
            <div class="stat-desc">{gettext("Last 30 days")}</div>
          </div>
          <div class="stat">
            <div class="stat-title">{gettext("Stickiness")}</div>
            <div class="stat-value">{Float.round(@stickiness * 100, 1)}%</div>
            <div class="stat-desc">{gettext("DAU / MAU")}</div>
          </div>
        </div>

        <%!-- DAU trend --%>
        <h2 class="text-lg font-semibold mb-3">{gettext("Daily Active Users")}</h2>
        <div :if={@dau_trend == []} class="text-base-content/60 text-sm mb-8">
          {gettext("No session data available.")}
        </div>
        <div :if={@dau_trend != []} class="overflow-x-auto mb-8">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Date")}</th>
                <th class="text-right">{gettext("Active Users")}</th>
                <th class="w-48"></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @dau_trend}>
                <td>{row.date}</td>
                <td class="text-right">{row.count}</td>
                <td>
                  <progress
                    class="progress progress-accent w-full"
                    value={row.count}
                    max={@max_dau}
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Feature engagement --%>
        <h2 class="text-lg font-semibold mb-3">{gettext("Feature Engagement")}</h2>
        <div :if={@engagement == []} class="text-base-content/60 text-sm">
          {gettext("No engagement data available.")}
        </div>
        <div :if={@engagement != []} class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Event")}</th>
                <th class="text-right">{gettext("Count")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @engagement}>
                <td>{format_event_name(row.event)}</td>
                <td class="text-right font-mono">{row.count}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_event_name(event) do
    event
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
