defmodule AniminaWeb.Admin.AnalyticsPagesLive do
  use AniminaWeb, :live_view

  alias Animina.Analytics
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_days: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Analytics — Pages"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    days = parse_days(params["days"])

    pages = Analytics.top_pages(days, 50)

    max_views =
      if pages == [], do: 1, else: max(Enum.max_by(pages, & &1.view_count).view_count, 1)

    {:noreply,
     assign(socket,
       days: days,
       pages: pages,
       max_views: max_views
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto">
        <div class="mb-6">
          <.link
            navigate={~p"/admin/analytics"}
            class="text-sm text-base-content/60 hover:text-base-content"
          >
            &larr; {gettext("Analytics")}
          </.link>
        </div>

        <.header>
          {gettext("Page Views by Path")}
          <:subtitle>{gettext("Top pages over the selected period")}</:subtitle>
        </.header>

        <%!-- Date range selector --%>
        <div class="flex gap-2 mt-4 mb-6">
          <.link
            :for={d <- [7, 30, 90]}
            patch={~p"/admin/analytics/pages?#{%{days: d}}"}
            class={"btn btn-sm #{if @days == d, do: "btn-primary", else: "btn-ghost"}"}
          >
            {ngettext("%{count} day", "%{count} days", d)}
          </.link>
        </div>

        <div :if={@pages == []} class="text-base-content/60 text-sm">
          {gettext("No data yet. Rollup runs daily at 03:00.")}
        </div>

        <div :if={@pages != []} class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>#</th>
                <th>{gettext("Path")}</th>
                <th class="text-right">{gettext("Views")}</th>
                <th class="text-right">{gettext("Sessions")}</th>
                <th class="text-right">{gettext("Users")}</th>
                <th class="w-48"></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{page, idx} <- Enum.with_index(@pages, 1)}>
                <td>{idx}</td>
                <td class="font-mono text-sm">{page.path}</td>
                <td class="text-right">{page.view_count}</td>
                <td class="text-right">{page.unique_sessions}</td>
                <td class="text-right">{page.unique_users}</td>
                <td>
                  <progress
                    class="progress progress-primary w-full"
                    value={page.view_count}
                    max={@max_views}
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
