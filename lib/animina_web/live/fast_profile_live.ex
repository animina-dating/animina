defmodule AniminaWeb.FastProfileLive do
  @moduledoc """
  Fast User Profile Liveview
  """

  use AniminaWeb, :live_view

  @impl true
  def mount(%{"username" => username}, %{"language" => language}, socket) do
    {:ok, socket |> assign(username: username)}
  end

  @impl true
  def mount(_params, _session, _socket) do
    raise Animina.Fallback
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      Fast Profile Page, username is <%= @username %>
    </div>
    """
  end
end
