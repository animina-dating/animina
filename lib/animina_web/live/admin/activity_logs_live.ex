defmodule AniminaWeb.Admin.ActivityLogsLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.ActivityLog
  alias Animina.ActivityLog.ActivityLogEntry
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers,
    only: [parse_int: 2, format_datetime: 1]

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Activity Logs"),
       live_mode: false,
       user_search: "",
       user_results: [],
       selected_user: nil
     )}
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

    # Load selected user if user_id is in params
    selected_user =
      if filter_user_id && filter_user_id != "" do
        Accounts.get_user(filter_user_id)
      else
        socket.assigns[:selected_user]
        |> then(fn
          user when not is_nil(user) and filter_user_id in [nil, ""] -> nil
          user -> user
        end)
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
     assign(socket,
       logs: result.entries,
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
       selected_user: selected_user
     )}
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

    {:noreply, assign(socket, live_mode: new_state)}
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
  def handle_event("filter-event", %{"event" => event}, socket) do
    filter = if event == "", do: nil, else: event
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_event: filter))}
  end

  @impl true
  def handle_event("filter-date-from", %{"date_from" => date}, socket) do
    val = if date == "", do: nil, else: date
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, date_from: val))}
  end

  @impl true
  def handle_event("filter-date-to", %{"date_to" => date}, socket) do
    val = if date == "", do: nil, else: date
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, date_to: val))}
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

  @impl true
  def handle_event("change-per-page", %{"per_page" => per_page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, per_page: per_page))}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: page))}
  end

  # --- PubSub ---

  @impl true
  def handle_info({:new_activity_log, entry}, socket) do
    if socket.assigns.live_mode && matches_filters?(entry, socket.assigns) do
      logs = [entry | socket.assigns.logs]
      {:noreply, assign(socket, logs: logs, total_count: socket.assigns.total_count + 1)}
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

  defp parse_sort_dir("asc"), do: :asc
  defp parse_sort_dir(_), do: :desc

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

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, ""), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp relative_time(nil), do: ""

  defp relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> gettext("%{count}s ago", count: diff)
      diff < 3600 -> gettext("%{count}m ago", count: div(diff, 60))
      diff < 86_400 -> gettext("%{count}h ago", count: div(diff, 3600))
      true -> gettext("%{count}d ago", count: div(diff, 86_400))
    end
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
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <.link navigate={~p"/admin/logs"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left-mini" class="h-4 w-4" />
            </.link>
            <h1 class="text-2xl font-bold text-base-content">{gettext("Activity Logs")}</h1>
          </div>
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
          <label class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2 cursor-pointer">
            <span class="text-sm text-base-content/60">{gettext("Live")}</span>
            <input
              type="checkbox"
              class="toggle toggle-sm toggle-primary"
              checked={@live_mode}
              phx-click="toggle-live"
            />
          </label>
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
          <div class="form-control">
            <div class="label">
              <span class="label-text">{gettext("Per page")}</span>
            </div>
            <div class="join">
              <%= for size <- [50, 100, 250, 500] do %>
                <button
                  class={[
                    "btn btn-sm join-item",
                    if(@per_page == size, do: "btn-active")
                  ]}
                  phx-click="change-per-page"
                  phx-value-per_page={size}
                >
                  {size}
                </button>
              <% end %>
            </div>
          </div>
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
            <tbody>
              <%= for log <- @logs do %>
                <tr class="hover:bg-base-200/50">
                  <td>
                    <span class="text-xs" title={format_datetime(log.inserted_at)}>
                      {relative_time(log.inserted_at)}
                    </span>
                  </td>
                  <td>
                    <span class={["badge badge-sm", category_badge_class(log.category)]}>
                      {log.category}
                    </span>
                  </td>
                  <td><span class="badge badge-sm badge-ghost">{log.event}</span></td>
                  <td class="text-xs">
                    <%= if log.actor do %>
                      <.link
                        navigate={~p"/users/#{log.actor_id}"}
                        class="link link-hover"
                      >
                        {log.actor.display_name}
                      </.link>
                    <% else %>
                      <span class="text-base-content/40">{gettext("System")}</span>
                    <% end %>
                  </td>
                  <td class="text-xs">
                    <%= if log.subject do %>
                      <.link
                        navigate={~p"/users/#{log.subject_id}"}
                        class="link link-hover"
                      >
                        {log.subject.display_name}
                      </.link>
                    <% end %>
                  </td>
                  <td class="max-w-md truncate text-sm">{log.summary}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Pagination (hidden in live mode) --%>
        <%= unless @live_mode do %>
          <.pagination page={@page} total_pages={@total_pages} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp pagination(assigns) do
    ~H"""
    <%= if @total_pages > 1 do %>
      <div class="flex justify-center mt-6">
        <div class="join">
          <button
            class={["join-item btn btn-sm", if(@page <= 1, do: "btn-disabled")]}
            phx-click="go-to-page"
            phx-value-page={max(@page - 1, 1)}
          >
            «
          </button>
          <%= for p <- visible_pages(@page, @total_pages) do %>
            <%= if p == :gap do %>
              <button class="join-item btn btn-sm btn-disabled">…</button>
            <% else %>
              <button
                class={["join-item btn btn-sm", if(p == @page, do: "btn-active")]}
                phx-click="go-to-page"
                phx-value-page={p}
              >
                {p}
              </button>
            <% end %>
          <% end %>
          <button
            class={["join-item btn btn-sm", if(@page >= @total_pages, do: "btn-disabled")]}
            phx-click="go-to-page"
            phx-value-page={min(@page + 1, @total_pages)}
          >
            »
          </button>
        </div>
      </div>
    <% end %>
    """
  end

  defp visible_pages(_current, total) when total <= 7, do: Enum.to_list(1..total)

  defp visible_pages(current, total) do
    pages = [1]
    pages = if current > 3, do: pages ++ [:gap], else: pages
    middle_start = max(2, current - 1)
    middle_end = min(total - 1, current + 1)
    pages = pages ++ Enum.to_list(middle_start..middle_end)
    pages = if current < total - 2, do: pages ++ [:gap], else: pages
    pages = pages ++ [total]
    Enum.uniq(pages)
  end
end
