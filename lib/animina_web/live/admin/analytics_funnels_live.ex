defmodule AniminaWeb.Admin.AnalyticsFunnelsLive do
  use AniminaWeb, :live_view

  alias Animina.Analytics
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_days: 1]

  @funnel_steps [:visitors, :registered, :profile_completed, :first_message, :mutual_match]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Analytics — Funnels"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    days = parse_days(params["days"])

    totals = Analytics.funnel_totals(days)
    daily = Analytics.funnel_stats(days)

    {:noreply,
     assign(socket,
       days: days,
       totals: totals,
       daily: daily,
       funnel_bars: build_funnel_bars(totals)
     )}
  end

  defp build_funnel_bars(totals) do
    max_val = max(totals.visitors || 0, 1)

    Enum.map(@funnel_steps, fn step ->
      val = Map.get(totals, step) || 0
      %{step: step, label: step_label(step), value: val, pct: Float.round(val / max_val * 100, 1)}
    end)
  end

  defp step_label(:visitors), do: gettext("Visitors")
  defp step_label(:registered), do: gettext("Registered")
  defp step_label(:profile_completed), do: gettext("Profile Completed")
  defp step_label(:first_message), do: gettext("First Message")
  defp step_label(:mutual_match), do: gettext("Mutual Match")

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
          {gettext("Conversion Funnel")}
          <:subtitle>{gettext("From visitor to mutual match")}</:subtitle>
        </.header>

        <%!-- Date range selector --%>
        <div class="flex gap-2 mt-4 mb-6">
          <.link
            :for={d <- [7, 30, 90]}
            patch={~p"/admin/analytics/funnels?#{%{days: d}}"}
            class={"btn btn-sm #{if @days == d, do: "btn-primary", else: "btn-ghost"}"}
          >
            {ngettext("%{count} day", "%{count} days", d)}
          </.link>
        </div>

        <%!-- Funnel bars --%>
        <div class="space-y-3 mb-8">
          <div :for={{bar, idx} <- Enum.with_index(@funnel_bars)} class="flex items-center gap-3">
            <div class="w-40 text-sm font-medium text-right">{bar.label}</div>
            <div class="flex-1">
              <progress
                class="progress progress-primary w-full h-6"
                value={bar.value}
                max={max(Enum.at(@funnel_bars, 0).value, 1)}
              />
            </div>
            <div class="w-20 text-sm text-right font-mono">{bar.value}</div>
            <div class="w-16 text-xs text-base-content/60 text-right">
              {conversion_rate(idx, @funnel_bars)}
            </div>
          </div>
        </div>

        <%!-- Daily trend --%>
        <h2 class="text-lg font-semibold mb-3">{gettext("Daily Breakdown")}</h2>
        <div :if={@daily == []} class="text-base-content/60 text-sm">
          {gettext("No data yet. Rollup runs daily at 03:00.")}
        </div>
        <div :if={@daily != []} class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Date")}</th>
                <th class="text-right">{gettext("Visitors")}</th>
                <th class="text-right">{gettext("Registered")}</th>
                <th class="text-right">{gettext("Profile")}</th>
                <th class="text-right">{gettext("1st Message")}</th>
                <th class="text-right">{gettext("Match")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @daily}>
                <td>{row.date}</td>
                <td class="text-right">{row.visitors}</td>
                <td class="text-right">{row.registered}</td>
                <td class="text-right">{row.profile_completed}</td>
                <td class="text-right">{row.first_message}</td>
                <td class="text-right">{row.mutual_match}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp conversion_rate(0, _bars), do: ""

  defp conversion_rate(idx, bars) do
    prev = Enum.at(bars, idx - 1).value
    curr = Enum.at(bars, idx).value

    if prev > 0 do
      "#{Float.round(curr / prev * 100, 1)}%"
    else
      "-"
    end
  end
end
