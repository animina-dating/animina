defmodule AniminaWeb.Admin.UserRolesLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.UserRole

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Manage Roles"),
       search_query: "",
       search_results: [],
       selected_user: nil,
       selected_user_roles: []
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    results = Accounts.search_users(query)
    {:noreply, assign(socket, search_query: query, search_results: results)}
  end

  def handle_event("select_user", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    roles = Accounts.get_user_roles(user)
    {:noreply, assign(socket, selected_user: user, selected_user_roles: roles)}
  end

  def handle_event("add_role", %{"role" => role}, socket) do
    user = socket.assigns.selected_user

    admin = socket.assigns.current_scope.user

    case Accounts.assign_role(user, role, originator: admin) do
      {:ok, _} ->
        roles = Accounts.get_user_roles(user)
        {:noreply, assign(socket, selected_user_roles: roles)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not add role."))}
    end
  end

  def handle_event("remove_role", %{"role" => role}, socket) do
    user = socket.assigns.selected_user

    admin = socket.assigns.current_scope.user

    case Accounts.remove_role(user, role, originator: admin) do
      {:ok, _} ->
        roles = Accounts.get_user_roles(user)
        {:noreply, assign(socket, selected_user_roles: roles)}

      {:error, :last_admin} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Cannot remove the last admin. Assign another admin first.")
         )}

      {:error, :implicit_role} ->
        {:noreply, put_flash(socket, :error, gettext("The user role cannot be removed."))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, gettext("Role not found."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/admin"}>{gettext("Admin")}</.link>
            </li>
            <li>{gettext("Manage Roles")}</li>
          </ul>
        </div>
        <h1 class="text-2xl font-bold text-base-content mb-6">{gettext("Manage Roles")}</h1>

        <div class="mb-6">
          <form phx-submit="search" phx-change="search">
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder={gettext("Search users by email or name...")}
              class="input input-bordered w-full"
              autocomplete="off"
              phx-debounce="300"
            />
          </form>
        </div>

        <%= if @search_results != [] do %>
          <div class="bg-base-200 rounded-lg divide-y divide-base-300 mb-6">
            <%= for user <- @search_results do %>
              <button
                phx-click="select_user"
                phx-value-id={user.id}
                class={[
                  "block w-full text-start px-4 py-3 hover:bg-base-300 transition-colors",
                  @selected_user && @selected_user.id == user.id && "bg-primary/10"
                ]}
              >
                <p class="text-sm font-medium text-base-content">{user.display_name}</p>
                <p class="text-xs text-base-content/50">{user.email}</p>
              </button>
            <% end %>
          </div>
        <% end %>

        <%= if @selected_user do %>
          <div class="bg-base-200 rounded-lg p-6">
            <h2 class="text-lg font-semibold text-base-content mb-1">
              {@selected_user.display_name}
            </h2>
            <p class="text-sm text-base-content/50 mb-4">{@selected_user.email}</p>

            <h3 class="text-sm font-semibold text-base-content/70 uppercase tracking-wider mb-2">
              {gettext("Current Roles")}
            </h3>
            <div class="flex flex-wrap gap-2 mb-4">
              <%= for role <- @selected_user_roles do %>
                <span class={[
                  "inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium",
                  role == "admin" && "bg-red-100 text-red-800",
                  role == "moderator" && "bg-yellow-100 text-yellow-800",
                  role == "user" && "bg-base-300 text-base-content/70"
                ]}>
                  {role}
                  <%= if role != "user" do %>
                    <button
                      phx-click="remove_role"
                      phx-value-role={role}
                      class="ml-1 text-current/50 hover:text-current"
                      title={gettext("Remove role")}
                    >
                      <.icon name="hero-x-mark-mini" class="size-4" />
                    </button>
                  <% end %>
                </span>
              <% end %>
            </div>

            <h3 class="text-sm font-semibold text-base-content/70 uppercase tracking-wider mb-2">
              {gettext("Add Role")}
            </h3>
            <div class="flex gap-2">
              <%= for role <- UserRole.valid_roles() do %>
                <%= if role not in @selected_user_roles do %>
                  <button
                    phx-click="add_role"
                    phx-value-role={role}
                    class="btn btn-sm btn-outline"
                  >
                    + {role}
                  </button>
                <% end %>
              <% end %>
              <%= if Enum.all?(UserRole.valid_roles(), &(&1 in @selected_user_roles)) do %>
                <p class="text-sm text-base-content/50 italic">
                  {gettext("All roles assigned.")}
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
