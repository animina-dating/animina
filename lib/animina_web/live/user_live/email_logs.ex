defmodule AniminaWeb.UserLive.EmailLogs do
  use AniminaWeb, :live_view

  alias Animina.Emails
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_int: 2, format_datetime: 1]

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Email History"),
       expanded: MapSet.new()
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user_id = socket.assigns.current_scope.user.id
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    sort_by = parse_sort_by(params["sort_by"])
    sort_dir = parse_sort_dir(params["sort_dir"])
    filter_type = params["type"]
    filter_status = params["status"]

    result =
      Emails.list_email_logs(
        page: page,
        per_page: per_page,
        sort_by: sort_by,
        sort_dir: sort_dir,
        filter_type: filter_type,
        filter_status: filter_status,
        user_id: user_id
      )

    email_types = Emails.distinct_email_types()

    {:noreply,
     assign(socket,
       logs: result.entries,
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages,
       sort_by: sort_by,
       sort_dir: sort_dir,
       filter_type: filter_type,
       filter_status: filter_status,
       available_types: email_types
     )}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: page))}
  end

  @impl true
  def handle_event("change-per-page", %{"per_page" => per_page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, per_page: per_page))}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    col = parse_sort_by(column)

    new_dir =
      if socket.assigns.sort_by == col do
        if socket.assigns.sort_dir == :desc, do: :asc, else: :desc
      else
        :desc
      end

    {:noreply,
     push_patch(socket,
       to: build_path(socket, page: 1, sort_by: col, sort_dir: new_dir)
     )}
  end

  @impl true
  def handle_event("filter-type", %{"type" => type}, socket) do
    filter = if type == "", do: nil, else: type
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_type: filter))}
  end

  @impl true
  def handle_event("filter-status", %{"status" => status}, socket) do
    filter = if status == "", do: nil, else: status
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_status: filter))}
  end

  @impl true
  def handle_event("toggle-expand", %{"id" => id}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded, id) do
        MapSet.delete(socket.assigns.expanded, id)
      else
        MapSet.put(socket.assigns.expanded, id)
      end

    {:noreply, assign(socket, expanded: expanded)}
  end

  # --- Helpers ---

  defp parse_sort_by("email_type"), do: :email_type
  defp parse_sort_by("status"), do: :status
  defp parse_sort_by("inserted_at"), do: :inserted_at
  defp parse_sort_by(_), do: :inserted_at

  defp parse_sort_dir("asc"), do: :asc
  defp parse_sort_dir(_), do: :desc

  defp build_path(socket, overrides) do
    params =
      %{
        page: Keyword.get(overrides, :page, socket.assigns.page),
        per_page: Keyword.get(overrides, :per_page, socket.assigns.per_page),
        sort_by: Keyword.get(overrides, :sort_by, socket.assigns.sort_by),
        sort_dir: Keyword.get(overrides, :sort_dir, socket.assigns.sort_dir)
      }
      |> maybe_put(:type, Keyword.get(overrides, :filter_type, socket.assigns.filter_type))
      |> maybe_put(:status, Keyword.get(overrides, :filter_status, socket.assigns.filter_status))

    ~p"/users/settings/emails?#{params}"
  end

  defp maybe_put(params, _key, nil), do: params
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

  defp sort_indicator(assigns) do
    ~H"""
    <%= if @sort_by == @column do %>
      <span class="ml-1">{if @sort_dir == :asc, do: "\u25B2", else: "\u25BC"}</span>
    <% end %>
    """
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <%!-- Breadcrumbs --%>
        <div class="text-sm breadcrumbs mb-4">
          <ul>
            <li>
              <.link navigate={~p"/users/settings"} class="link link-hover">
                {gettext("Settings")}
              </.link>
            </li>
            <li>{gettext("Email History")}</li>
          </ul>
        </div>

        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Email History")}</h1>
          <span class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} email",
              "%{count} emails",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Filters --%>
        <div class="flex flex-wrap items-end gap-4 mb-4">
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Type")}</span>
            </div>
            <select class="select select-bordered select-sm" phx-change="filter-type" name="type">
              <option value="" selected={is_nil(@filter_type)}>{gettext("All")}</option>
              <%= for type <- @available_types do %>
                <option value={type} selected={@filter_type == type}>{type}</option>
              <% end %>
            </select>
          </label>

          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Status")}</span>
            </div>
            <select
              class="select select-bordered select-sm"
              phx-change="filter-status"
              name="status"
            >
              <option value="" selected={is_nil(@filter_status)}>{gettext("All")}</option>
              <option value="sent" selected={@filter_status == "sent"}>{gettext("Sent")}</option>
              <option value="error" selected={@filter_status == "error"}>
                {gettext("Error")}
              </option>
            </select>
          </label>

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
                <th>{gettext("Subject")}</th>
                <th>{gettext("Recipient")}</th>
                <th
                  class="cursor-pointer hover:bg-base-200"
                  phx-click="sort"
                  phx-value-column="status"
                >
                  {gettext("Status")}
                  <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:status} />
                </th>
                <th
                  class="cursor-pointer hover:bg-base-200"
                  phx-click="sort"
                  phx-value-column="inserted_at"
                >
                  {gettext("Date")}
                  <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:inserted_at} />
                </th>
              </tr>
            </thead>
            <tbody>
              <%= if @logs == [] do %>
                <tr>
                  <td colspan="4" class="text-center py-8 text-base-content/50">
                    {gettext("No emails found.")}
                  </td>
                </tr>
              <% end %>
              <%= for log <- @logs do %>
                <tr
                  class={[
                    "cursor-pointer hover:bg-base-200/50",
                    if(log.status == "error", do: "bg-error/5")
                  ]}
                  phx-click="toggle-expand"
                  phx-value-id={log.id}
                >
                  <td class="max-w-xs truncate">{log.subject}</td>
                  <td class="max-w-[10rem] truncate text-xs" title={log.recipient}>
                    {log.recipient}
                  </td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      if(log.status == "sent", do: "badge-success", else: "badge-error")
                    ]}>
                      {log.status}
                    </span>
                  </td>
                  <td>
                    <span class="text-xs" title={format_datetime(log.inserted_at)}>
                      {relative_time(log.inserted_at)}
                    </span>
                  </td>
                </tr>
                <%= if MapSet.member?(@expanded, log.id) do %>
                  <tr class="bg-base-200/30">
                    <td colspan="4" class="p-4">
                      <pre class="text-xs whitespace-pre-wrap break-words max-h-96 overflow-y-auto bg-base-100 p-3 rounded-lg">{log.body}</pre>
                    </td>
                  </tr>
                <% end %>
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
