defmodule AniminaWeb.ProfileLive do
  @moduledoc """
  User Profile Liveview
  """
  use AniminaWeb, :live_view

  @impl true
  def mount(%{"username" => username}, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(active_tab: :home)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      Profile
    </div>
    """
  end
end
