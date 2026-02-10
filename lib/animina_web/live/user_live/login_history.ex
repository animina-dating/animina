defmodule AniminaWeb.UserLive.LoginHistory do
  use AniminaWeb, :live_view

  alias Animina.ActivityLog
  alias AniminaWeb.Helpers.UserAgentParser
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers,
    only: [parse_int: 2, format_datetime: 1]

  use AniminaWeb.Helpers.PaginationHelpers, sort: true

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Login History")
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user_id = socket.assigns.current_scope.user.id
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    sort_dir = parse_sort_dir(params["sort_dir"])
    filter_event = params["event"]

    result =
      ActivityLog.list_auth_events_for_user(user_id,
        page: page,
        per_page: per_page,
        sort_dir: sort_dir,
        filter_event: filter_event
      )

    heatmap_data = ActivityLog.login_heatmap_data(user_id)

    {:noreply,
     assign(socket,
       logs: result.entries,
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages,
       sort_by: :inserted_at,
       sort_dir: sort_dir,
       filter_event: filter_event,
       heatmap_data: heatmap_data
     )}
  end

  @impl true
  def handle_event("filter-event", %{"event" => event}, socket) do
    filter = if event == "", do: nil, else: event
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_event: filter))}
  end

  # --- Helpers ---

  defp parse_sort_by("inserted_at"), do: :inserted_at
  defp parse_sort_by(_), do: :inserted_at

  defp build_path(socket, overrides) do
    params =
      %{
        page: Keyword.get(overrides, :page, socket.assigns.page),
        per_page: Keyword.get(overrides, :per_page, socket.assigns.per_page),
        sort_dir: Keyword.get(overrides, :sort_dir, socket.assigns.sort_dir)
      }
      |> maybe_put(:event, Keyword.get(overrides, :filter_event, socket.assigns.filter_event))

    ~p"/my/logs/logins?#{params}"
  end

  defp event_badge_class("login_email"), do: "badge-success"
  defp event_badge_class("login_passkey"), do: "badge-info"
  defp event_badge_class("logout"), do: "badge-ghost"
  defp event_badge_class("login_failed"), do: "badge-error"
  defp event_badge_class(_), do: "badge-ghost"

  defp event_label("login_email"), do: gettext("Email Login")
  defp event_label("login_passkey"), do: gettext("Passkey Login")
  defp event_label("logout"), do: gettext("Logout")
  defp event_label("login_failed"), do: gettext("Failed Login")
  defp event_label(event), do: event

  defp event_icon("login_email"), do: "hero-envelope-micro"
  defp event_icon("login_passkey"), do: "hero-key-micro"
  defp event_icon("logout"), do: "hero-arrow-right-start-on-rectangle-micro"
  defp event_icon("login_failed"), do: "hero-x-circle-micro"
  defp event_icon(_), do: "hero-question-mark-circle-micro"

  defp device_summary(metadata) when is_map(metadata) do
    case Map.get(metadata, "user_agent") do
      nil -> gettext("Unknown")
      ua -> UserAgentParser.summary(ua)
    end
  end

  defp device_summary(_), do: gettext("Unknown")

  defp device_icon(metadata) when is_map(metadata) do
    case Map.get(metadata, "user_agent") do
      nil -> "hero-globe-alt"
      ua -> UserAgentParser.device_icon(ua)
    end
  end

  defp device_icon(_), do: "hero-globe-alt"

  # --- Heatmap helpers ---

  defp heatmap_weeks(heatmap_data) do
    today = Date.utc_today()
    # Start from 52 weeks ago, aligned to Monday
    start_date = Date.add(today, -364)
    # Align to Monday (1 = Monday in Date.day_of_week)
    day_of_week = Date.day_of_week(start_date)
    start_monday = Date.add(start_date, -(day_of_week - 1))

    # Generate all dates from start_monday to today
    days = Date.diff(today, start_monday)

    Enum.map(0..days, fn offset ->
      date = Date.add(start_monday, offset)
      count = Map.get(heatmap_data, date, 0)
      {date, count}
    end)
    |> Enum.chunk_every(7)
  end

  defp heatmap_color(0), do: "fill-base-300"
  defp heatmap_color(1), do: "fill-success/30"
  defp heatmap_color(n) when n in 2..3, do: "fill-success/50"
  defp heatmap_color(n) when n in 4..5, do: "fill-success/70"
  defp heatmap_color(_), do: "fill-success"

  defp month_labels(weeks) do
    weeks
    |> Enum.with_index()
    |> Enum.filter(fn {week, _idx} ->
      case week do
        [{date, _} | _] -> date.day <= 7
        _ -> false
      end
    end)
    |> Enum.map(fn {[{date, _} | _], idx} -> {idx, month_abbr(date.month)} end)
  end

  defp month_abbr(1), do: gettext("Jan")
  defp month_abbr(2), do: gettext("Feb")
  defp month_abbr(3), do: gettext("Mar")
  defp month_abbr(4), do: gettext("Apr")
  defp month_abbr(5), do: gettext("May")
  defp month_abbr(6), do: gettext("Jun")
  defp month_abbr(7), do: gettext("Jul")
  defp month_abbr(8), do: gettext("Aug")
  defp month_abbr(9), do: gettext("Sep")
  defp month_abbr(10), do: gettext("Oct")
  defp month_abbr(11), do: gettext("Nov")
  defp month_abbr(12), do: gettext("Dec")

  defp format_heatmap_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    weeks = heatmap_weeks(assigns.heatmap_data)
    month_labels = month_labels(weeks)

    assigns =
      assigns
      |> assign(:weeks, weeks)
      |> assign(:month_labels, month_labels)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <%!-- Breadcrumbs --%>
        <div class="text-sm breadcrumbs mb-4">
          <ul>
            <li>
              <.link navigate={~p"/my"} class="link link-hover">
                {gettext("My ANIMINA")}
              </.link>
            </li>
            <li>
              <.link navigate={~p"/my/logs"} class="link link-hover">
                {gettext("Logs")}
              </.link>
            </li>
            <li>{gettext("Login History")}</li>
          </ul>
        </div>

        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Login History")}</h1>
          <span class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} event",
              "%{count} events",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Heatmap --%>
        <div class="mb-8">
          <h2 class="text-sm font-semibold text-base-content/70 mb-3">{gettext("Login Activity")}</h2>
          <div class="overflow-x-auto">
            <svg
              viewBox={"0 0 #{length(@weeks) * 15 + 40} 130"}
              class="w-full max-w-3xl"
              role="img"
              aria-label={gettext("Login Activity")}
            >
              <%!-- Month labels --%>
              <g>
                <%= for {col, label} <- @month_labels do %>
                  <text
                    x={col * 15 + 40}
                    y="10"
                    class="fill-base-content/50"
                    font-size="10"
                    font-family="sans-serif"
                  >
                    {label}
                  </text>
                <% end %>
              </g>
              <%!-- Day-of-week labels --%>
              <text x="0" y="35" class="fill-base-content/50" font-size="9" font-family="sans-serif">
                {gettext("Mon")}
              </text>
              <text x="0" y="57" class="fill-base-content/50" font-size="9" font-family="sans-serif">
                {gettext("Wed")}
              </text>
              <text x="0" y="79" class="fill-base-content/50" font-size="9" font-family="sans-serif">
                {gettext("Fri")}
              </text>
              <%!-- Cells --%>
              <g>
                <%= for {week, col} <- Enum.with_index(@weeks) do %>
                  <%= for {{date, count}, row} <- Enum.with_index(week) do %>
                    <rect
                      x={col * 15 + 40}
                      y={row * 15 + 20}
                      width="12"
                      height="12"
                      rx="2"
                      class={heatmap_color(count)}
                    >
                      <title>
                        {format_heatmap_date(date)}: {ngettext(
                          "%{count} login",
                          "%{count} logins",
                          count,
                          count: count
                        )}
                      </title>
                    </rect>
                  <% end %>
                <% end %>
              </g>
            </svg>
          </div>
          <%!-- Legend --%>
          <div class="flex items-center gap-1 mt-2 text-xs text-base-content/60">
            <span>{gettext("Less")}</span>
            <span class="inline-block w-3 h-3 rounded-sm bg-base-300"></span>
            <span class="inline-block w-3 h-3 rounded-sm bg-success/30"></span>
            <span class="inline-block w-3 h-3 rounded-sm bg-success/50"></span>
            <span class="inline-block w-3 h-3 rounded-sm bg-success/70"></span>
            <span class="inline-block w-3 h-3 rounded-sm bg-success"></span>
            <span>{gettext("More")}</span>
          </div>
        </div>

        <%!-- Filters --%>
        <div class="flex flex-wrap items-end gap-4 mb-4">
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Event")}</span>
            </div>
            <select class="select select-bordered select-sm" phx-change="filter-event" name="event">
              <option value="" selected={is_nil(@filter_event)}>{gettext("All")}</option>
              <option value="login_email" selected={@filter_event == "login_email"}>
                {gettext("Email Login")}
              </option>
              <option value="login_passkey" selected={@filter_event == "login_passkey"}>
                {gettext("Passkey Login")}
              </option>
              <option value="logout" selected={@filter_event == "logout"}>
                {gettext("Logout")}
              </option>
              <option value="login_failed" selected={@filter_event == "login_failed"}>
                {gettext("Failed Login")}
              </option>
            </select>
          </label>

          <.per_page_selector per_page={@per_page} />
        </div>

        <%!-- Table --%>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Event")}</th>
                <th>{gettext("Device")}</th>
                <th class="hidden sm:table-cell">{gettext("Summary")}</th>
                <th
                  class="cursor-pointer hover:bg-base-200"
                  phx-click="sort"
                  phx-value-column="inserted_at"
                >
                  {gettext("Date")}
                  <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:inserted_at} />
                </th>
              </tr>
            </thead>
            <tbody>
              <%= if @logs == [] do %>
                <tr>
                  <td colspan="4" class="text-center py-8 text-base-content/50">
                    {gettext("No login events found.")}
                  </td>
                </tr>
              <% end %>
              <%= for log <- @logs do %>
                <tr class={[
                  "hover:bg-base-200/50",
                  if(log.event == "login_failed", do: "bg-error/5")
                ]}>
                  <td>
                    <span
                      class={["badge badge-sm", event_badge_class(log.event)]}
                      title={event_label(log.event)}
                    >
                      <.icon
                        name={event_icon(log.event)}
                        class="h-3.5 w-3.5 sm:hidden"
                      />
                      <span class="hidden sm:inline">{event_label(log.event)}</span>
                    </span>
                  </td>
                  <td>
                    <div class="flex items-center gap-2">
                      <.icon name={device_icon(log.metadata)} class="h-4 w-4 text-base-content/50" />
                      <span class="text-xs">{device_summary(log.metadata)}</span>
                    </div>
                  </td>
                  <td class="hidden sm:table-cell max-w-xs truncate text-xs">{log.summary}</td>
                  <td>
                    <span class="text-xs" title={format_datetime(log.inserted_at)}>
                      {relative_time(log.inserted_at)}
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Pagination --%>
        <.pagination page={@page} total_pages={@total_pages} />
      </div>
    </Layouts.app>
    """
  end
end
