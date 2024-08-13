defmodule AniminaWeb.WaitlistComponents do
  @moduledoc """
  Provides Waitlist UI components.
  """
  use Phoenix.Component
  import AniminaWeb.Gettext
  import AniminaWeb.CoreComponents
  use PhoenixHTMLHelpers

  def waitlist_users_table(assigns) do
    ~H"""
    <div>
      <p class="my-3 dark:text-white text-black text-xl">
        <%= gettext("The following users are on the waitlist") %>
      </p>

      <div class="overflow-hidden border-b dark:border-gray-700 border-gray-200 rounded shadow">
        <table class="min-w-full text-left bg-white table-auto ">
          <thead>
            <tr class="text-white dark:bg-gray-700 bg-gray-800">
              <th class="px-4 py-3"><%= gettext("Name") %></th>
              <th class="px-4 py-3"><%= gettext("Profile") %></th>
              <th class="px-4 py-3"><%= gettext("Email") %></th>
              <th class="px-4 py-3"><%= gettext("Action") %></th>
            </tr>
          </thead>
          <tbody class="">
            <%= for user <- @users do %>
              <tr>
                <td class="px-4 py-3"><%= user.name %></td>
                <td class="px-4 text-blue-500 py-3">
                  <a href={"/#{user.username}"}><%= user.username %></a>
                </td>
                <td class="px-4 py-3"><%= user.email %></td>
                <td class="px-4 py-3">
                  <button
                    phx-value-id={user.id}
                    phx-click="give_user_in_waitlist_access"
                    data-confirm="Are You Sure?"
                    class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
                  >
                    <%= gettext("Give Access") %>
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
