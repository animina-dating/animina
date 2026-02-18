defmodule AniminaWeb.Admin.ActivityLogsLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.ActivityLog
  alias Animina.ActivityLog.ActivityLogEntry
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers,
    only: [parse_int: 2, format_datetime: 1]

  use AniminaWeb.Helpers.PaginationHelpers,
    filter_events: [
      {"filter-event", "event", :filter_event},
      {"filter-date-from", "date_from", :date_from},
      {"filter-date-to", "date_to", :date_to}
    ]

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Activity Logs"),
       live_mode: false,
       user_search: "",
       user_results: [],
       selected_user: nil,
       new_log_ids: MapSet.new(),
       modal_photo_id: nil
     )
     |> stream(:logs, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    sort_dir = parse_sort_dir(params["sort_dir"])
    filter_category = params["category"]
    filter_event = params["event"]
    filter_user_id = params["user_id"]
    date_from = params["date_from"]
    date_to = params["date_to"]

    # Load selected user if user_id is in params, clear if filter removed
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
      ActivityLog.list_activity_logs(
        page: page,
        per_page: per_page,
        sort_dir: sort_dir,
        filter_category: filter_category,
        filter_event: filter_event,
        filter_user_id: filter_user_id,
        date_from: date_from,
        date_to: date_to
      )

    available_events =
      if filter_category && filter_category != "" do
        ActivityLogEntry.events_for_category(filter_category)
      else
        ActivityLogEntry.valid_events()
      end

    {:noreply,
     socket
     |> assign(
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages,
       sort_dir: sort_dir,
       filter_category: filter_category,
       filter_event: filter_event,
       filter_user_id: filter_user_id,
       date_from: date_from,
       date_to: date_to,
       available_events: available_events,
       selected_user: selected_user,
       new_log_ids: MapSet.new()
     )
     |> stream(:logs, result.entries, reset: true)}
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("toggle-live", _params, socket) do
    new_state = !socket.assigns.live_mode

    if new_state do
      Phoenix.PubSub.subscribe(Animina.PubSub, ActivityLog.pubsub_topic())
    else
      Phoenix.PubSub.unsubscribe(Animina.PubSub, ActivityLog.pubsub_topic())
    end

    {:noreply, assign(socket, live_mode: new_state, new_log_ids: MapSet.new())}
  end

  @impl true
  def handle_event("filter-category", %{"category" => category}, socket) do
    filter = if category == "", do: nil, else: category

    {:noreply,
     push_patch(socket,
       to: build_path(socket, page: 1, filter_category: filter, filter_event: nil)
     )}
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
  def handle_event("filter-by-actor", %{"id" => user_id}, socket) do
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

  @impl true
  def handle_event("show-photo", %{"photo-id" => photo_id}, socket) do
    {:noreply, assign(socket, modal_photo_id: photo_id)}
  end

  @impl true
  def handle_event("close-photo", _params, socket) do
    {:noreply, assign(socket, modal_photo_id: nil)}
  end

  # --- PubSub ---

  @impl true
  def handle_info({:new_activity_log, entry}, socket) do
    if socket.assigns.live_mode && matches_filters?(entry, socket.assigns) do
      new_ids = MapSet.put(socket.assigns.new_log_ids, entry.id)

      {:noreply,
       socket
       |> assign(total_count: socket.assigns.total_count + 1, new_log_ids: new_ids)
       |> stream_insert(:logs, entry, at: 0)}
    else
      {:noreply, socket}
    end
  end

  # --- Helpers ---

  defp matches_filters?(entry, assigns) do
    matches_field?(entry.category, assigns.filter_category) &&
      matches_field?(entry.event, assigns.filter_event) &&
      matches_user?(entry, assigns.filter_user_id)
  end

  defp matches_field?(_value, nil), do: true
  defp matches_field?(_value, ""), do: true
  defp matches_field?(value, filter), do: value == filter

  defp matches_user?(_entry, nil), do: true
  defp matches_user?(_entry, ""), do: true

  defp matches_user?(entry, user_id),
    do: entry.actor_id == user_id || entry.subject_id == user_id

  defp build_path(socket, overrides) do
    params =
      %{
        page: Keyword.get(overrides, :page, socket.assigns.page),
        per_page: Keyword.get(overrides, :per_page, socket.assigns.per_page),
        sort_dir: Keyword.get(overrides, :sort_dir, socket.assigns.sort_dir)
      }
      |> maybe_put(
        :category,
        Keyword.get(overrides, :filter_category, socket.assigns.filter_category)
      )
      |> maybe_put(:event, Keyword.get(overrides, :filter_event, socket.assigns.filter_event))
      |> maybe_put(
        :user_id,
        Keyword.get(overrides, :filter_user_id, socket.assigns.filter_user_id)
      )
      |> maybe_put(:date_from, Keyword.get(overrides, :date_from, socket.assigns.date_from))
      |> maybe_put(:date_to, Keyword.get(overrides, :date_to, socket.assigns.date_to))

    ~p"/admin/logs/activity?#{params}"
  end

  defp photo_thumbnail_url(photo_id) do
    signature = Animina.Photos.compute_signature(photo_id)
    "/photos/#{signature}/#{photo_id}_thumb.webp"
  end

  defp photo_full_url(photo_id) do
    signature = Animina.Photos.compute_signature(photo_id)
    "/photos/#{signature}/#{photo_id}.webp"
  end

  defp category_badge_class("auth"), do: "badge-primary"
  defp category_badge_class("social"), do: "badge-secondary"
  defp category_badge_class("profile"), do: "badge-accent"
  defp category_badge_class("admin"), do: "badge-warning"
  defp category_badge_class("system"), do: "badge-info"
  defp category_badge_class(_), do: "badge-ghost"

  # --- Render ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <.breadcrumb_nav>
          <:crumb navigate={~p"/admin"}>{gettext("Admin")}</:crumb>
          <:crumb navigate={~p"/admin/logs"}>{gettext("Logs")}</:crumb>
          <:crumb>{gettext("Activity Logs")}</:crumb>
        </.breadcrumb_nav>
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Activity Logs")}</h1>
          <span class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} entry",
              "%{count} entries",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Live toggle --%>
        <div class="flex flex-wrap gap-3 mb-6">
          <div
            class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2 cursor-pointer"
            phx-click="toggle-live"
          >
            <span class="text-sm text-base-content/60">{gettext("Live")}</span>
            <input
              type="checkbox"
              class="toggle toggle-sm toggle-primary"
              checked={@live_mode}
              tabindex="-1"
            />
          </div>
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

          <%!-- Category --%>
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Category")}</span>
            </div>
            <select
              class="select select-bordered select-sm"
              phx-change="filter-category"
              name="category"
            >
              <option value="" selected={is_nil(@filter_category)}>{gettext("All")}</option>
              <%= for cat <- ActivityLogEntry.valid_categories() do %>
                <option value={cat} selected={@filter_category == cat}>{cat}</option>
              <% end %>
            </select>
          </label>

          <%!-- Event --%>
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Event")}</span>
            </div>
            <select
              class="select select-bordered select-sm"
              phx-change="filter-event"
              name="event"
            >
              <option value="" selected={is_nil(@filter_event)}>{gettext("All")}</option>
              <%= for event <- @available_events do %>
                <option value={event} selected={@filter_event == event}>{event}</option>
              <% end %>
            </select>
          </label>

          <%!-- Date From --%>
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("From")}</span>
            </div>
            <input
              type="date"
              class="input input-bordered input-sm"
              value={@date_from}
              phx-change="filter-date-from"
              name="date_from"
            />
          </label>

          <%!-- Date To --%>
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("To")}</span>
            </div>
            <input
              type="date"
              class="input input-bordered input-sm"
              value={@date_to}
              phx-change="filter-date-to"
              name="date_to"
            />
          </label>

          <%!-- Per Page --%>
          <.per_page_selector per_page={@per_page} />
        </div>

        <%!-- Table --%>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Time")}</th>
                <th>{gettext("Category")}</th>
                <th>{gettext("Event")}</th>
                <th>{gettext("Actor")}</th>
                <th>{gettext("Subject")}</th>
                <th>{gettext("Summary")}</th>
              </tr>
            </thead>
            <tbody id="logs" phx-update="stream">
              <tr
                :for={{dom_id, log} <- @streams.logs}
                id={dom_id}
                class={[
                  "hover:bg-base-200/50",
                  log.id in @new_log_ids && "animate-highlight-row"
                ]}
              >
                <td>
                  <span class="text-xs">{format_datetime(log.inserted_at)}</span>
                </td>
                <td>
                  <span class={["badge badge-sm", category_badge_class(log.category)]}>
                    {log.category}
                  </span>
                </td>
                <td><span class="badge badge-sm badge-ghost">{log.event}</span></td>
                <td class="text-xs">
                  <%= if log.actor do %>
                    <a
                      phx-click="filter-by-actor"
                      phx-value-id={log.actor_id}
                      class="link link-hover cursor-pointer"
                      title={gettext("Filter by this user")}
                    >
                      {log.actor.display_name}
                    </a>
                  <% else %>
                    <span class="text-base-content/40">{gettext("System")}</span>
                  <% end %>
                </td>
                <td class="text-xs">
                  <%= if log.subject do %>
                    <a
                      phx-click="filter-by-actor"
                      phx-value-id={log.subject_id}
                      class="link link-hover cursor-pointer"
                      title={gettext("Filter by this user")}
                    >
                      {log.subject.display_name}
                    </a>
                  <% end %>
                </td>
                <td class="max-w-md text-sm">
                  <div class="flex items-center gap-2">
                    <%= if photo_id = log.metadata["photo_id"] do %>
                      <img
                        src={photo_thumbnail_url(photo_id)}
                        class="w-8 h-8 rounded object-cover flex-shrink-0 cursor-pointer hover:opacity-80"
                        loading="lazy"
                        phx-click="show-photo"
                        phx-value-photo-id={photo_id}
                      />
                    <% end %>
                    <%= if job_id = log.metadata["job_id"] do %>
                      <.link
                        navigate={~p"/admin/logs/ai?job_id=#{job_id}"}
                        class="link link-hover truncate"
                      >
                        {log.summary}
                      </.link>
                    <% else %>
                      <span class="truncate">{log.summary}</span>
                    <% end %>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Pagination (hidden in live mode) --%>
        <%= unless @live_mode do %>
          <.pagination page={@page} total_pages={@total_pages} />
        <% end %>

        <%!-- Photo modal --%>
        <%= if @modal_photo_id do %>
          <div class="modal modal-open">
            <div class="modal-box max-w-2xl p-2">
              <button
                type="button"
                phx-click="close-photo"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2 z-10"
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
              <img
                src={photo_full_url(@modal_photo_id)}
                class="w-full h-auto rounded"
              />
            </div>
            <div class="modal-backdrop" phx-click="close-photo"></div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
