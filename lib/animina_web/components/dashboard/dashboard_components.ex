defmodule AniminaWeb.DashboardComponents do
  @moduledoc """
  Provides Dashboard UI components.
  """
  use Phoenix.Component
  import AniminaWeb.Gettext

  def dashboard_card_component(assigns) do
    ~H"""
    <div class="flex flex-col rounded-md gap-4 cursor-pointer h-[180px] bg-gray-100 dark:bg-gray-800 p-2">
      <h1 class="p-2 rounded-md dark:bg-gray-700 bg-white text-black  dark:text-white text-center">
        <%= @title %>
      </h1>
    </div>
    """
  end

  def dashboard_card_like_component(assigns) do
    ~H"""
    <div class="flex flex-col rounded-md gap-3 cursor-pointer h-[180px] bg-gray-100 dark:bg-gray-800 p-2">
      <h1 class="p-2 rounded-md dark:bg-gray-700 bg-white text-black  font-semibod text-xl  dark:text-white text-center">
        <%= @title %>
      </h1>

      <div class="flex flex-col gap-3">
        <div class="flex flex-col dark:text-white  text-black gap-1">
          <p>
            <%= gettext("You have received a total of") %> <%= @total_likes_received_by_user %> <%= gettext(
              "likes"
            ) %>
          </p>

          <p :if={@likes_received_by_user_in_seven_days > 0} class="italic">
            <%= @likes_received_by_user_in_seven_days %> <%= gettext("in the last 7 days.") %>
          </p>
        </div>

        <div class="flex flex-col dark:text-white  text-black gap-1">
          <p>
            <%= gettext("You liked") %>
            <.link navigate="/my/bookmarks/liked" class="text-blue-500">
              <%= @profiles_liked_by_user %>
              <span :if={@profiles_liked_by_user == 1}><%= gettext("profile") %></span>
              <span :if={@profiles_liked_by_user != 1}><%= gettext("profiles") %></span>
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
