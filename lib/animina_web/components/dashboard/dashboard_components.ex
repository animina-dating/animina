defmodule AniminaWeb.DashboardComponents do
  @moduledoc """
  Provides Dashboard UI components.
  """
  use Phoenix.Component
  alias Animina.Markdown

  def dashboard_card_component(assigns) do
    ~H"""
    <div class="flex flex-col rounded-md gap-4 h-[300px] bg-gray-800 p-2">
      <h1 class="p-2 rounded-md bg-gray-700 text-white text-center">
        <%= @title %>
      </h1>
    </div>
    """
  end
end
