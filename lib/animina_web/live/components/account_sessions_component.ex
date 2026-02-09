defmodule AniminaWeb.AccountSessionsComponent do
  @moduledoc false
  use AniminaWeb, :live_component

  alias AniminaWeb.Helpers.UserAgentParser

  @impl true
  def render(assigns) do
    ~H"""
    <div id="sessions-section">
      <h2 class="text-xs font-semibold uppercase tracking-wider text-base-content/50 mb-3">
        {gettext("Active Sessions")}
      </h2>

      <div :if={length(@sessions) > 1} class="mb-6">
        <button
          phx-click="revoke_all_other"
          data-confirm={gettext("Log out of all other devices?")}
          class="btn btn-outline btn-sm btn-error"
        >
          {gettext("Log out all other devices")}
        </button>
      </div>

      <div class="space-y-3">
        <div
          :for={session <- @sessions}
          class={[
            "flex items-start gap-4 p-4 rounded-lg border",
            if(session.id == @current_session_id,
              do: "border-primary bg-primary/5",
              else: "border-base-300"
            )
          ]}
        >
          <span class="flex-shrink-0 mt-1 text-base-content/60">
            <.icon name={UserAgentParser.device_icon(session.user_agent)} class="h-6 w-6" />
          </span>

          <div class="flex-1 min-w-0">
            <div class="font-semibold text-sm text-base-content">
              {UserAgentParser.summary(session.user_agent)}
              <span
                :if={session.id == @current_session_id}
                class="badge badge-primary badge-sm ml-2"
              >
                {gettext("This device")}
              </span>
            </div>

            <div class="text-xs text-base-content/60 mt-1 space-y-0.5">
              <div :if={session.ip_address}>
                IP: {session.ip_address}
              </div>
              <div>
                {gettext("Last active:")}
                {format_time(session.last_seen_at || session.inserted_at)}
              </div>
              <div>
                {gettext("Signed in:")}
                {format_time(session.inserted_at)}
              </div>
            </div>
          </div>

          <div :if={session.id != @current_session_id} class="flex-shrink-0">
            <button
              phx-click="revoke_session"
              phx-value-id={session.id}
              data-confirm={gettext("Log out this session?")}
              class="btn btn-ghost btn-xs text-error"
            >
              {gettext("Log out")}
            </button>
          </div>
        </div>
      </div>

      <div :if={@sessions == []} class="text-center text-base-content/60 py-8">
        {gettext("No active sessions found.")}
      </div>
    </div>
    """
  end

  defp format_time(nil), do: "-"

  defp format_time(dt) do
    dt
    |> DateTime.shift_zone!("Europe/Berlin", Tz.TimeZoneDatabase)
    |> Calendar.strftime("%d.%m.%Y %H:%M")
  end
end
