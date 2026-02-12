defmodule AniminaWeb.Admin.TosAcceptancesLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers,
    only: [parse_int: 2, format_datetime: 1]

  use AniminaWeb.Helpers.PaginationHelpers

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    versions = Accounts.list_tos_versions()

    {:ok,
     assign(socket,
       page_title: gettext("ToS Acceptances"),
       user_search: "",
       user_results: [],
       selected_user: nil,
       versions: versions
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    filter_version = params["version"]
    filter_user_id = params["user_id"]

    selected_user =
      cond do
        filter_user_id && filter_user_id != "" ->
          Accounts.get_user(filter_user_id)

        filter_user_id in [nil, ""] ->
          nil

        true ->
          socket.assigns[:selected_user]
      end

    result =
      Accounts.list_tos_acceptances(
        page: page,
        per_page: per_page,
        filter_user_id: filter_user_id,
        filter_version: filter_version
      )

    {:noreply,
     assign(socket,
       acceptances: result.entries,
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages,
       filter_version: filter_version,
       filter_user_id: filter_user_id,
       selected_user: selected_user
     )}
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("filter-version", %{"version" => version}, socket) do
    filter = if version == "", do: nil, else: version
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_version: filter))}
  end

  @impl true
  def handle_event("search-user", %{"user_search" => query}, socket) do
    results = if String.length(query) >= 2, do: Accounts.search_users(query), else: []
    {:noreply, assign(socket, user_search: query, user_results: results)}
  end

  @impl true
  def handle_event("select-user", %{"id" => user_id}, socket) do
    {:noreply,
     socket
     |> assign(user_search: "", user_results: [])
     |> push_patch(to: build_path(socket, page: 1, filter_user_id: user_id))}
  end

  @impl true
  def handle_event("clear-user", _params, socket) do
    {:noreply,
     socket
     |> assign(user_search: "", user_results: [], selected_user: nil)
     |> push_patch(to: build_path(socket, page: 1, filter_user_id: nil))}
  end

  # --- Helpers ---

  defp build_path(socket, overrides) do
    params =
      %{
        page: Keyword.get(overrides, :page, socket.assigns.page),
        per_page: Keyword.get(overrides, :per_page, socket.assigns.per_page)
      }
      |> maybe_put(
        :version,
        Keyword.get(overrides, :filter_version, socket.assigns.filter_version)
      )
      |> maybe_put(
        :user_id,
        Keyword.get(overrides, :filter_user_id, socket.assigns.filter_user_id)
      )

    ~p"/admin/tos-acceptances?#{params}"
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <%!-- Breadcrumb --%>
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/admin"}>{gettext("Admin")}</.link>
            </li>
            <li>
              <.link navigate={~p"/admin/logs"}>{gettext("Logs")}</.link>
            </li>
            <li>{gettext("ToS Acceptances")}</li>
          </ul>
        </div>
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("ToS Acceptances")}</h1>
          <span class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} entry",
              "%{count} entries",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Filters --%>
        <div class="flex flex-wrap items-end gap-4 mb-4">
          <%!-- User Search --%>
          <div class="form-control w-full max-w-xs relative">
            <div class="label">
              <span class="label-text">{gettext("User")}</span>
            </div>
            <%= if @selected_user do %>
              <div class="flex items-center gap-2 input input-bordered input-sm">
                <span class="flex-1 truncate">
                  {@selected_user.display_name}
                  <span class="text-xs text-base-content/50">{@selected_user.email}</span>
                </span>
                <button type="button" phx-click="clear-user" class="btn btn-ghost btn-xs">
                  <.icon name="hero-x-mark" class="h-3 w-3" />
                </button>
              </div>
            <% else %>
              <input
                type="text"
                class="input input-bordered input-sm"
                placeholder={gettext("Search by name or email...")}
                value={@user_search}
                phx-keyup="search-user"
                phx-debounce="300"
                name="user_search"
                autocomplete="off"
              />
              <%= if @user_results != [] do %>
                <ul class="absolute z-50 top-full mt-1 w-full bg-base-100 border border-base-300 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                  <%= for user <- @user_results do %>
                    <li
                      class="px-3 py-2 hover:bg-base-200 cursor-pointer text-sm"
                      phx-click="select-user"
                      phx-value-id={user.id}
                    >
                      <span class="font-medium">{user.display_name}</span>
                      <span class="text-base-content/50 ml-1">{user.email}</span>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            <% end %>
          </div>

          <%!-- Version --%>
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Version")}</span>
            </div>
            <select
              class="select select-bordered select-sm"
              phx-change="filter-version"
              name="version"
            >
              <option value="" selected={is_nil(@filter_version)}>{gettext("All")}</option>
              <%= for version <- @versions do %>
                <option value={version} selected={@filter_version == version}>{version}</option>
              <% end %>
            </select>
          </label>

          <%!-- Per Page --%>
          <.per_page_selector per_page={@per_page} />
        </div>

        <%!-- Table --%>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Accepted At")}</th>
                <th>{gettext("User")}</th>
                <th>{gettext("Version")}</th>
              </tr>
            </thead>
            <tbody>
              <%= for acceptance <- @acceptances do %>
                <tr class="hover:bg-base-200/50">
                  <td>
                    <span class="text-xs" title={format_datetime(acceptance.accepted_at)}>
                      {relative_time(acceptance.accepted_at)}
                    </span>
                  </td>
                  <td class="text-sm">
                    <%= if acceptance.user do %>
                      <.link
                        navigate={~p"/users/#{acceptance.user_id}"}
                        class="link link-hover"
                      >
                        {acceptance.user.display_name}
                      </.link>
                      <span class="text-xs text-base-content/50 ml-1">
                        {acceptance.user.email}
                      </span>
                    <% else %>
                      <span class="text-base-content/40">{gettext("Deleted user")}</span>
                    <% end %>
                  </td>
                  <td>
                    <span class="badge badge-sm badge-outline">{acceptance.version}</span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Pagination --%>
        <.pagination page={@page} total_pages={@total_pages} />
      </div>
    </Layouts.app>
    """
  end
end
