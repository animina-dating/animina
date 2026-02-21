defmodule AniminaWeb.Admin.AnalyticsOverviewLive do
  use AniminaWeb, :live_view

  alias Animina.Analytics
  alias AniminaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Analytics"))
     |> load_data()}
  end

  defp load_data(socket) do
    today = Analytics.today_stats()
    active_users = Analytics.active_user_counts()
    daily_totals = Analytics.daily_totals(30)
    top_pages = Analytics.top_pages_today(10)

    assign(socket,
      page_views_today: today.page_views,
      unique_sessions_today: today.unique_sessions,
      unique_users_today: today.unique_users,
      dau: active_users.dau,
      wau: active_users.wau,
      mau: active_users.mau,
      daily_totals: daily_totals,
      top_pages: top_pages,
      max_daily_views: max_daily_views(daily_totals)
    )
  end

  defp max_daily_views([]), do: 1
  defp max_daily_views(totals), do: max(Enum.max_by(totals, & &1.view_count).view_count, 1)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto">
        <.page_header
          title={gettext("Analytics")}
          subtitle={gettext("Self-hosted page view and engagement analytics")}
        >
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
        </.page_header>

        <%!-- Sub-page navigation cards --%>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-6 mb-8">
          <.link
            navigate={~p"/admin/analytics/pages"}
            class="card bg-base-200 hover:bg-base-300 transition-colors"
          >
            <div class="card-body p-4">
              <h3 class="card-title text-sm">{gettext("Pages")}</h3>
              <p class="text-xs text-base-content/60">{gettext("Page view breakdown by path")}</p>
            </div>
          </.link>
          <.link
            navigate={~p"/admin/analytics/funnels"}
            class="card bg-base-200 hover:bg-base-300 transition-colors"
          >
            <div class="card-body p-4">
              <h3 class="card-title text-sm">{gettext("Funnels")}</h3>
              <p class="text-xs text-base-content/60">
                {gettext("Registration and conversion funnel")}
              </p>
            </div>
          </.link>
          <.link
            navigate={~p"/admin/analytics/engagement"}
            class="card bg-base-200 hover:bg-base-300 transition-colors"
          >
            <div class="card-body p-4">
              <h3 class="card-title text-sm">{gettext("Engagement")}</h3>
              <p class="text-xs text-base-content/60">{gettext("DAU/WAU/MAU and feature usage")}</p>
            </div>
          </.link>
        </div>

        <%!-- Today's stats --%>
        <h2 class="text-lg font-semibold mb-3">{gettext("Today")}</h2>
        <div class="stats stats-vertical sm:stats-horizontal shadow w-full mb-8">
          <div class="stat">
            <div class="stat-title">{gettext("Page Views")}</div>
            <div class="stat-value">{@page_views_today}</div>
          </div>
          <div class="stat">
            <div class="stat-title">{gettext("Sessions")}</div>
            <div class="stat-value">{@unique_sessions_today}</div>
          </div>
          <div class="stat">
            <div class="stat-title">{gettext("Users")}</div>
            <div class="stat-value">{@unique_users_today}</div>
          </div>
        </div>

        <%!-- Active users --%>
        <h2 class="text-lg font-semibold mb-3">{gettext("Active Users")}</h2>
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
        </div>

        <%!-- 30-day page view trend --%>
        <h2 class="text-lg font-semibold mb-3">{gettext("30-Day Page View Trend")}</h2>
        <div :if={@daily_totals == []} class="text-base-content/60 text-sm mb-8">
          {gettext("No data yet. Rollup runs daily at 03:00.")}
        </div>
        <div :if={@daily_totals != []} class="overflow-x-auto mb-8">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Date")}</th>
                <th class="text-right">{gettext("Views")}</th>
                <th class="text-right">{gettext("Sessions")}</th>
                <th class="text-right">{gettext("Users")}</th>
                <th class="w-48"></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @daily_totals}>
                <td>{row.date}</td>
                <td class="text-right">{row.view_count}</td>
                <td class="text-right">{row.unique_sessions}</td>
                <td class="text-right">{row.unique_users}</td>
                <td>
                  <progress
                    class="progress progress-primary w-full"
                    value={row.view_count}
                    max={@max_daily_views}
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Top 10 pages today --%>
        <h2 class="text-lg font-semibold mb-3">{gettext("Top Pages Today")}</h2>
        <div :if={@top_pages == []} class="text-base-content/60 text-sm">
          {gettext("No page views recorded yet today.")}
        </div>
        <div :if={@top_pages != []} class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>#</th>
                <th>{gettext("Path")}</th>
                <th class="text-right">{gettext("Views")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{page, idx} <- Enum.with_index(@top_pages, 1)}>
                <td>{idx}</td>
                <td class="font-mono text-sm">{page.path}</td>
                <td class="text-right">{page.views}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
