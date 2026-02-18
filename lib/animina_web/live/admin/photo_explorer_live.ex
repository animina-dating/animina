defmodule AniminaWeb.Admin.PhotoExplorerLive do
  use AniminaWeb, :live_view

  alias Animina.Photos
  alias Animina.Photos.Photo

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_int: 2, format_datetime: 1]
  import AniminaWeb.Helpers.PaginationHelpers, only: [pagination: 1]

  @default_per_page 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Photo Explorer"),
       search_query: "",
       state_filter: nil,
       results: nil,
       page: 1,
       per_page: @default_per_page,
       total_count: 0,
       total_pages: 1
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, search_query: query, page: 1)
    {:noreply, do_search(socket)}
  end

  @impl true
  def handle_event("filter-state", %{"state" => state}, socket) do
    filter = if state == "", do: nil, else: state
    socket = assign(socket, state_filter: filter, page: 1)
    {:noreply, do_search(socket)}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    socket = assign(socket, page: parse_int(page, 1))
    {:noreply, do_search(socket)}
  end

  defp do_search(%{assigns: %{search_query: query}} = socket) when byte_size(query) < 2 do
    assign(socket, results: nil, total_count: 0, total_pages: 1)
  end

  defp do_search(socket) do
    %{search_query: query, page: page, per_page: per_page, state_filter: state} = socket.assigns

    result = Photos.search_photos(query, page: page, per_page: per_page, state: state)

    assign(socket,
      results: result.entries,
      page: result.page,
      per_page: result.per_page,
      total_count: result.total_count,
      total_pages: result.total_pages
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <.breadcrumb_nav>
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
          <:crumb>{gettext("Photo Explorer")}</:crumb>
        </.breadcrumb_nav>

        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Photo Explorer")}</h1>
          <span :if={@results} class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} photo",
              "%{count} photos",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Search & Filters --%>
        <div class="flex flex-wrap gap-4 mb-6">
          <form id="photo-search" phx-change="search" class="flex-1 min-w-64">
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder={gettext("Search by name, email, phone, or description...")}
              class="input input-bordered w-full"
              autocomplete="off"
              phx-debounce="300"
            />
          </form>
          <select
            id="state-filter"
            class="select select-bordered"
            phx-change="filter-state"
            name="state"
          >
            <option value="" selected={is_nil(@state_filter)}>{gettext("All states")}</option>
            <%= for state <- Photo.valid_states() do %>
              <option value={state} selected={@state_filter == state}>
                {state}
              </option>
            <% end %>
          </select>
        </div>

        <%!-- Results --%>
        <%= cond do %>
          <% is_nil(@results) -> %>
            <.empty_state
              icon="hero-magnifying-glass"
              title={gettext("Enter a search term to find photos.")}
              size={:lg}
            />
          <% @results == [] -> %>
            <.empty_state
              icon="hero-photo"
              title={gettext("No photos found matching your search.")}
              size={:lg}
            />
          <% true -> %>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>{gettext("Photo")}</th>
                    <th>{gettext("Owner")}</th>
                    <th>{gettext("State")}</th>
                    <th>{gettext("Description")}</th>
                    <th>{gettext("Created")}</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <%= for result <- @results do %>
                    <tr>
                      <td>
                        <img
                          src={Photos.signed_url(result.photo, :thumbnail)}
                          class="w-12 h-12 object-cover rounded"
                          loading="lazy"
                        />
                      </td>
                      <td>
                        <div class="font-medium text-sm">{result.user_display_name}</div>
                        <div class="text-xs text-base-content/50">{result.user_email}</div>
                      </td>
                      <td>
                        <span class={["badge badge-sm", state_badge_class(result.photo.state)]}>
                          {result.photo.state}
                        </span>
                      </td>
                      <td>
                        <span class="text-sm text-base-content/70 line-clamp-2 max-w-xs">
                          {result.photo.description || "-"}
                        </span>
                      </td>
                      <td>
                        <span class="text-xs text-base-content/50">
                          {format_datetime(result.photo.inserted_at)}
                        </span>
                      </td>
                      <td>
                        <.link
                          navigate={~p"/admin/photos/#{result.photo.id}"}
                          class="btn btn-xs btn-outline btn-primary"
                        >
                          {gettext("View")}
                        </.link>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <.pagination page={@page} total_pages={@total_pages} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp state_badge_class("approved"), do: "badge-success"
  defp state_badge_class("appeal_pending"), do: "badge-info"
  defp state_badge_class("appeal_rejected"), do: "badge-error"
  defp state_badge_class("no_face_error"), do: "badge-error"
  defp state_badge_class("error"), do: "badge-error"
  defp state_badge_class(_), do: "badge-warning"
end
