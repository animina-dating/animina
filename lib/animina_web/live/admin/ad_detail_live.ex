defmodule AniminaWeb.Admin.AdDetailLive do
  use AniminaWeb, :live_view

  alias Animina.Ads
  alias Animina.Ads.Ad
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_int: 2, format_datetime: 1]

  use AniminaWeb.Helpers.PaginationHelpers, filter_events: []

  @default_per_page 25

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Ads.get_ad(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Ad not found"))
         |> push_navigate(to: ~p"/admin/ads")}

      ad ->
        {:ok,
         socket
         |> assign(
           page_title: gettext("Ad #%{number}", number: ad.number),
           ad: ad,
           visit_count: Ads.count_visits(ad.id),
           visit_count_with_bots: Ads.count_visits(ad.id, exclude_bots: false),
           conversion_count: Ads.count_conversions(ad.id),
           conversion_rate: Ads.conversion_rate(ad.id),
           daily_counts: Ads.daily_visit_counts(ad.id),
           os_breakdown: Ads.visit_breakdown(ad.id, :os),
           browser_breakdown: Ads.visit_breakdown(ad.id, :browser),
           device_breakdown: Ads.visit_breakdown(ad.id, :device_type)
         )
         |> stream(:visits, [])}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)

    result = Ads.list_visits(socket.assigns.ad.id, page: page, per_page: per_page)

    {:noreply,
     socket
     |> assign(
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages
     )
     |> stream(:visits, result.entries, reset: true)}
  end

  defp build_path(socket, overrides) do
    ad = socket.assigns.ad

    params =
      %{
        "page" => socket.assigns[:page],
        "per_page" => socket.assigns[:per_page]
      }
      |> Map.merge(overrides)
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.new()

    ~p"/admin/ads/#{ad.id}?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto">
        <.breadcrumb_nav>
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
          <:crumb navigate={~p"/admin/ads"}>{gettext("Ad Campaigns")}</:crumb>
          <:crumb>{gettext("Ad #%{number}", number: @ad.number)}</:crumb>
        </.breadcrumb_nav>

        <%!-- Info Card --%>
        <div class="card bg-base-200 p-6 mb-6">
          <div class="flex flex-col sm:flex-row gap-6">
            <div class="flex-1">
              <h2 class="text-xl font-medium mb-4">
                {gettext("Ad #%{number}", number: @ad.number)}
                <span class={[
                  "badge badge-sm ml-2",
                  if(Ad.active?(@ad), do: "badge-success", else: "badge-neutral")
                ]}>
                  {if(Ad.active?(@ad), do: gettext("active"), else: gettext("inactive"))}
                </span>
              </h2>

              <dl class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                <div>
                  <dt class="text-base-content/50">{gettext("URL")}</dt>
                  <dd class="font-mono text-xs break-all">{@ad.url}</dd>
                </div>
                <div>
                  <dt class="text-base-content/50">{gettext("Description")}</dt>
                  <dd>{@ad.description || "—"}</dd>
                </div>
                <div>
                  <dt class="text-base-content/50">{gettext("Date range")}</dt>
                  <dd>{format_date_range(@ad)}</dd>
                </div>
                <div>
                  <dt class="text-base-content/50">{gettext("Created")}</dt>
                  <dd>{format_datetime(@ad.inserted_at)}</dd>
                </div>
              </dl>
            </div>

            <div :if={@ad.qr_code_path} class="flex flex-col items-center gap-2">
              <img
                src={~p"/admin/ads/#{@ad.id}/qr-code/show"}
                alt={gettext("QR Code")}
                class="w-32 h-32"
              />
              <a
                href={~p"/admin/ads/#{@ad.id}/qr-code"}
                class="btn btn-outline btn-xs"
                download
              >
                <.icon name="hero-arrow-down-tray-mini" class="w-3 h-3" />
                {gettext("Download QR")}
              </a>
            </div>
          </div>
        </div>

        <%!-- Stats Cards --%>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">{gettext("Visits")}</div>
            <div class="stat-value text-2xl">{@visit_count}</div>
            <div :if={@visit_count != @visit_count_with_bots} class="stat-desc text-xs">
              {gettext("%{count} incl. bots", count: @visit_count_with_bots)}
            </div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">{gettext("Conversions")}</div>
            <div class="stat-value text-2xl">{@conversion_count}</div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">{gettext("Conversion rate")}</div>
            <div class="stat-value text-2xl">{@conversion_rate}%</div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">{gettext("Bot visits")}</div>
            <div class="stat-value text-2xl">{@visit_count_with_bots - @visit_count}</div>
          </div>
        </div>

        <%!-- Daily Visits --%>
        <div :if={@daily_counts != []} class="card bg-base-200 p-6 mb-6">
          <h3 class="text-lg font-medium mb-4">{gettext("Daily Visits")}</h3>
          <table class="table table-zebra table-sm w-full">
            <thead>
              <tr>
                <th>{gettext("Date")}</th>
                <th class="text-right">{gettext("Visits")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{date, count} <- @daily_counts}>
                <td>{date}</td>
                <td class="text-right">{count}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Breakdowns --%>
        <div
          :if={@os_breakdown != [] or @browser_breakdown != [] or @device_breakdown != []}
          class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6"
        >
          <.breakdown_card title={gettext("By OS")} data={@os_breakdown} />
          <.breakdown_card title={gettext("By Browser")} data={@browser_breakdown} />
          <.breakdown_card title={gettext("By Device")} data={@device_breakdown} />
        </div>

        <%!-- Recent Visits Table --%>
        <div class="card bg-base-200 p-6">
          <h3 class="text-lg font-medium mb-4">{gettext("Recent Visits")}</h3>
          <div class="overflow-x-auto">
            <table class="table table-zebra table-sm w-full">
              <thead>
                <tr>
                  <th>{gettext("Time")}</th>
                  <th>{gettext("IP")}</th>
                  <th>{gettext("OS")}</th>
                  <th>{gettext("Browser")}</th>
                  <th>{gettext("Device")}</th>
                  <th>{gettext("Language")}</th>
                  <th>{gettext("Bot?")}</th>
                </tr>
              </thead>
              <tbody id="visits" phx-update="stream">
                <tr :for={{dom_id, visit} <- @streams.visits} id={dom_id}>
                  <td class="text-xs">{format_datetime(visit.visited_at)}</td>
                  <td class="font-mono text-xs">{visit.ip_address}</td>
                  <td class="text-xs">{visit.os || "—"}</td>
                  <td class="text-xs">{visit.browser || "—"}</td>
                  <td class="text-xs">{visit.device_type || "—"}</td>
                  <td class="text-xs">{visit.language || "—"}</td>
                  <td>
                    <span :if={visit.is_bot} class="badge badge-warning badge-xs">bot</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div :if={@total_count == 0} class="text-center py-6 text-base-content/50">
            {gettext("No visits recorded yet.")}
          </div>

          <div :if={@total_pages > 1} class="mt-4 flex items-center justify-between">
            <.per_page_selector per_page={@per_page} sizes={[10, 25, 50]} />
            <.pagination page={@page} total_pages={@total_pages} />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp breakdown_card(assigns) do
    ~H"""
    <div class="card bg-base-200 p-4">
      <h4 class="text-sm font-medium mb-2">{@title}</h4>
      <dl class="space-y-1">
        <div :for={{label, count} <- @data} class="flex justify-between text-sm">
          <dt>{label || "—"}</dt>
          <dd class="font-mono">{count}</dd>
        </div>
      </dl>
      <p :if={@data == []} class="text-xs text-base-content/50">{gettext("No data")}</p>
    </div>
    """
  end

  defp format_date_range(%{starts_on: nil, ends_on: nil}), do: gettext("Always active")

  defp format_date_range(%{starts_on: starts, ends_on: nil}),
    do: gettext("From %{date}", date: starts)

  defp format_date_range(%{starts_on: nil, ends_on: ends}),
    do: gettext("Until %{date}", date: ends)

  defp format_date_range(%{starts_on: starts, ends_on: ends}),
    do: "#{starts} – #{ends}"
end
