defmodule AniminaWeb.WaitlistComponents do
  @moduledoc """
  Provides Waitlist UI components.
  """
  use Phoenix.Component
  import AniminaWeb.Gettext
  use PhoenixHTMLHelpers
  import Gettext, only: [with_locale: 2]

  def waitlist_users_table(assigns) do
    ~H"""
    <div>
      <p class="my-3 dark:text-white text-black text-xl">
        <%= with_locale(@language, fn -> %>
          <%= gettext("The following users are on the waitlist") %>
        <% end) %>
      </p>

      <div class="overflow-hidden border-b dark:border-gray-700 border-gray-200 rounded shadow">
        <table class="min-w-full text-left bg-white table-auto ">
          <thead>
            <tr class="text-white dark:bg-gray-700 bg-gray-800">
              <th class="px-4 py-3">
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Name") %>
                <% end) %>

                <%=  %>
              </th>
              <th class="px-4 py-3">
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Profile") %>
                <% end) %>
              </th>
              <th class="px-4 py-3">
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Email") %>
                <% end) %>
              </th>
              <th class="px-4 py-3">
                <%= with_locale(@language, fn -> %>
                  <%= gettext("Action") %>
                <% end) %>
              </th>
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
                    id={"user-in-waitlist-#{user.id}"}
                    phx-click="give_user_in_waitlist_access"
                    data-confirm="Are You Sure?"
                    class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
                  >
                    <%= with_locale(@language, fn -> %>
                      <%= gettext("Give Access") %>
                    <% end) %>
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
