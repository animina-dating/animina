defmodule AniminaWeb.UserLive.ProfileHub do
  @moduledoc """
  Redirects /my-profile to /settings (the unified profile & settings page).
  Kept as a route target for bookmarks and cached links.
  """

  use AniminaWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}></Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/settings")}
  end
end
