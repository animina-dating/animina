defmodule AniminaWeb.AnalyticsHook do
  @moduledoc """
  LiveView on_mount hook that records page views.

  Attaches to `:handle_params` so that every navigation event
  (initial mount, live_patch, live_redirect) is tracked.

  Page view inserts are async (Task.start) so they never block rendering.

  Gated by `config :animina, :analytics_tracking` (defaults to true).
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  alias Animina.Analytics

  def on_mount(:track_page_view, _params, session, socket) do
    if tracking_enabled?() do
      analytics_session_id = session["analytics_session_id"]

      socket =
        socket
        |> assign(:analytics_session_id, analytics_session_id)
        |> assign(:analytics_previous_path, nil)
        |> attach_hook(:analytics_page_view, :handle_params, &handle_params/3)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  defp handle_params(_params, uri, socket) do
    path = URI.parse(uri).path
    previous_path = socket.assigns[:analytics_previous_path]
    session_id = socket.assigns[:analytics_session_id]

    user_id =
      case socket.assigns do
        %{current_scope: %{user: %{id: id}}} -> id
        _ -> nil
      end

    if session_id do
      Task.start(fn ->
        Analytics.record_page_view(%{
          session_id: session_id,
          path: path,
          referrer_path: previous_path,
          user_id: user_id
        })
      end)
    end

    {:cont, assign(socket, :analytics_previous_path, path)}
  end

  defp tracking_enabled? do
    Application.get_env(:animina, :analytics_tracking, true)
  end
end
