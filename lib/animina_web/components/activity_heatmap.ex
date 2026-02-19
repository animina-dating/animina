defmodule AniminaWeb.ActivityHeatmap do
  @moduledoc """
  Shared function component for rendering a GitHub-style activity heatmap SVG.
  Used on the login history page and the public moodboard profile.
  """

  use Phoenix.Component
  use Gettext, backend: AniminaWeb.Gettext

  @doc """
  Renders an activity heatmap SVG from a map of `%{Date.t() => integer()}`.

  ## Attributes

    * `data` — required, `%{Date.t() => integer()}` of daily counts
    * `label` — optional heading text (defaults to "Activity")
  """
  attr :data, :map, required: true
  attr :label, :string, default: nil

  def activity_heatmap(assigns) do
    weeks = heatmap_weeks(assigns.data)
    month_labels = month_labels(weeks)

    day_labels = [
      {0, gettext("Mon")},
      {1, gettext("Tue")},
      {2, gettext("Wed")},
      {3, gettext("Thu")},
      {4, gettext("Fri")},
      {5, gettext("Sat")},
      {6, gettext("Sun")}
    ]

    assigns =
      assigns
      |> assign(:weeks, weeks)
      |> assign(:month_labels, month_labels)
      |> assign(:day_labels, day_labels)
      |> assign_new(:label, fn -> gettext("Activity") end)

    ~H"""
    <div id="activity-heatmap">
      <h2 :if={@label} class="text-sm font-semibold text-base-content/70 mb-3">{@label}</h2>
      <div class="overflow-x-auto">
        <svg
          viewBox={"0 0 #{length(@weeks) * 15 + 32} 130"}
          class="w-full max-w-md"
          role="img"
          aria-label={@label || gettext("Activity")}
        >
          <%!-- Month labels --%>
          <g>
            <%= for {col, label} <- @month_labels do %>
              <text
                x={col * 15 + 32}
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
          <%= for {row, label} <- @day_labels do %>
            <text
              x="0"
              y={row * 15 + 31}
              class="fill-base-content/50"
              font-size="9"
              font-family="sans-serif"
            >
              {label}
            </text>
          <% end %>
          <%!-- Cells --%>
          <g>
            <%= for {week, col} <- Enum.with_index(@weeks) do %>
              <%= for {{date, count}, row} <- Enum.with_index(week) do %>
                <rect
                  x={col * 15 + 32}
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
    """
  end

  # --- Heatmap helpers ---

  defp heatmap_weeks(heatmap_data) do
    today = Date.utc_today()
    start_date = Date.add(today, -120)
    day_of_week = Date.day_of_week(start_date)
    start_monday = Date.add(start_date, -(day_of_week - 1))

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
end
