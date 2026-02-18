defmodule AniminaWeb.Helpers.PaginationHelpers do
  @moduledoc """
  Shared pagination, sorting, and time formatting helpers for LiveViews.

  Provides reusable components and functions used across admin and user
  log pages that display paginated, sortable tables.

  ## Usage

  For components and helper functions only:

      import AniminaWeb.Helpers.PaginationHelpers

  To also get shared `handle_event` callbacks for `"change-per-page"`,
  `"go-to-page"`, and `"sort"`, use the macro form instead:

      use AniminaWeb.Helpers.PaginationHelpers

  The calling module must define a private `build_path(socket, overrides)`
  function. For the `"sort"` handler, it must also define
  `parse_sort_by(column_string)`.

  ## Options

    * `:sort` — generates a `"sort"` event handler (default `false`)
    * `:expand` — generates a `"toggle-expand"` event handler (default `false`)
    * `:filter_events` — list of `{event_name, param_key, build_path_key}`
      tuples that generate filter event handlers. Each tuple generates a
      `handle_event` that reads the param, converts `""` to `nil`, and
      calls `push_patch` with `page: 1` and the given `build_path_key`.

      Example:

          use AniminaWeb.Helpers.PaginationHelpers,
            filter_events: [
              {"filter-type", "type", :filter_type},
              {"filter-status", "status", :filter_status}
            ]
  """

  defmacro __using__(opts) do
    sort? = Keyword.get(opts, :sort, false)
    expand? = Keyword.get(opts, :expand, false)

    filter_events =
      opts
      |> Keyword.get(:filter_events, [])
      |> Enum.map(fn
        {:{}, _, [event_name, param_key, build_path_key]} ->
          {event_name, param_key, build_path_key}

        {event_name, param_key} ->
          {event_name, param_key}
      end)

    filter_handlers =
      for {event_name, param_key, build_path_key} <- filter_events do
        quote do
          @impl true
          def handle_event(unquote(event_name), %{unquote(param_key) => value}, socket) do
            filter = if value == "", do: nil, else: value

            {:noreply,
             push_patch(socket,
               to: build_path(socket, [{:page, 1}, {unquote(build_path_key), filter}])
             )}
          end
        end
      end

    quote do
      import AniminaWeb.Helpers.PaginationHelpers

      @impl true
      def handle_event("change-per-page", %{"per_page" => per_page}, socket) do
        {:noreply, push_patch(socket, to: build_path(socket, page: 1, per_page: per_page))}
      end

      @impl true
      def handle_event("go-to-page", %{"page" => page}, socket) do
        {:noreply, push_patch(socket, to: build_path(socket, page: page))}
      end

      if unquote(sort?) do
        @impl true
        def handle_event("sort", %{"column" => column}, socket) do
          col = parse_sort_by(column)

          new_dir =
            cond do
              socket.assigns.sort_by != col -> :desc
              socket.assigns.sort_dir == :desc -> :asc
              true -> :desc
            end

          {:noreply,
           push_patch(socket,
             to: build_path(socket, page: 1, sort_by: col, sort_dir: new_dir)
           )}
        end
      end

      if unquote(expand?) do
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
      end

      unquote_splicing(filter_handlers)
    end
  end

  use Phoenix.Component
  use Gettext, backend: AniminaWeb.Gettext

  @doc """
  Renders a per-page size selector as a button group.

  Emits `"change-per-page"` events with a `per_page` value.

  ## Examples

      <.per_page_selector per_page={@per_page} />
      <.per_page_selector per_page={@per_page} sizes={[50, 100, 150, 500]} />
  """
  attr :per_page, :integer, required: true
  attr :sizes, :list, default: [50, 100, 250, 500]

  def per_page_selector(assigns) do
    ~H"""
    <div class="form-control">
      <div class="label">
        <span class="label-text">{gettext("Per page")}</span>
      </div>
      <div class="join">
        <%= for size <- @sizes do %>
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
    """
  end

  @doc """
  Renders a pagination component with page buttons and prev/next navigation.

  Expects `page` and `total_pages` assigns. Emits `"go-to-page"` events
  with a `page` value.

  ## Examples

      <.pagination page={@page} total_pages={@total_pages} />
  """
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true

  def pagination(assigns) do
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

  @doc """
  Renders a sort direction indicator (triangle) for table column headers.

  Shows ▲ for ascending and ▼ for descending when the column matches.

  ## Examples

      <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:inserted_at} />
  """
  attr :sort_by, :atom, required: true
  attr :sort_dir, :atom, required: true
  attr :column, :atom, required: true

  def sort_indicator(assigns) do
    ~H"""
    <%= if @sort_by == @column do %>
      <span class="ml-1">{if @sort_dir == :asc, do: "\u25B2", else: "\u25BC"}</span>
    <% end %>
    """
  end

  @doc """
  Computes which page numbers to display in pagination, inserting `:gap`
  atoms where pages are skipped.

  ## Examples

      iex> visible_pages(1, 5)
      [1, 2, 3, 4, 5]

      iex> visible_pages(5, 10)
      [1, :gap, 4, 5, 6, :gap, 10]
  """
  def visible_pages(_current, total) when total <= 7, do: Enum.to_list(1..total)

  def visible_pages(current, total) do
    left_gap = if current > 3, do: [:gap], else: []
    middle = Enum.to_list(max(2, current - 1)..min(total - 1, current + 1))
    right_gap = if current < total - 2, do: [:gap], else: []

    Enum.uniq([1] ++ left_gap ++ middle ++ right_gap ++ [total])
  end

  @doc """
  Formats a datetime as a human-readable relative time string.

  ## Examples

      iex> relative_time(nil)
      ""

      # Returns strings like "5s ago", "3m ago", "2h ago", "1d ago"
  """
  def relative_time(nil), do: ""

  def relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> gettext("%{count}s ago", count: diff)
      diff < 3600 -> gettext("%{count}m ago", count: div(diff, 60))
      diff < 86_400 -> gettext("%{count}h ago", count: div(diff, 3600))
      true -> gettext("%{count}d ago", count: div(diff, 86_400))
    end
  end

  @doc """
  Parses a sort direction string, defaulting to `:desc`.

  ## Examples

      iex> parse_sort_dir("asc")
      :asc

      iex> parse_sort_dir("desc")
      :desc

      iex> parse_sort_dir(nil)
      :desc
  """
  def parse_sort_dir("asc"), do: :asc
  def parse_sort_dir(_), do: :desc

  @doc """
  Puts a key-value pair into a map, skipping nil and empty string values.

  Useful for building query parameter maps where blank filters should be omitted.

  ## Examples

      iex> maybe_put(%{page: 1}, :type, "sent")
      %{page: 1, type: "sent"}

      iex> maybe_put(%{page: 1}, :type, nil)
      %{page: 1}

      iex> maybe_put(%{page: 1}, :type, "")
      %{page: 1}
  """
  def maybe_put(params, _key, nil), do: params
  def maybe_put(params, _key, ""), do: params
  def maybe_put(params, key, value), do: Map.put(params, key, value)
end
