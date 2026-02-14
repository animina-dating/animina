defmodule AniminaWeb.Admin.AIJobsLive do
  use AniminaWeb, :live_view

  alias Animina.AI
  alias Animina.AI.Semaphore
  alias Animina.Photos
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers,
    only: [parse_int: 2, format_datetime: 1]

  use AniminaWeb.Helpers.PaginationHelpers, sort: true

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("AI Jobs"),
       auto_reload: false,
       show_bulk_retry_modal: false,
       bulk_retry_range: nil,
       bulk_retry_count: 0,
       show_regenerate_modal: false,
       regenerate_count: 0,
       detail_job: nil,
       detail_tab: "result",
       enlarged_photo: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    sort_by = parse_sort_by(params["sort_by"])
    sort_dir = parse_sort_dir(params["sort_dir"])
    filter_job_type = params["job_type"]
    filter_status = params["status"]
    filter_priority = params["priority"]
    filter_model = params["model"]
    queue_only = params["view"] == "queue"

    result =
      AI.list_jobs(
        page: page,
        per_page: per_page,
        sort_by: sort_by,
        sort_dir: sort_dir,
        filter_job_type: filter_job_type,
        filter_status: filter_status,
        filter_priority: filter_priority,
        filter_model: filter_model,
        queue_only: queue_only
      )

    stats = AI.queue_stats()
    semaphore = safe_semaphore_status()
    paused = AI.queue_paused?()
    models = AI.distinct_models()
    job_types = AI.distinct_job_types()

    {:noreply,
     assign(socket,
       jobs: result.entries,
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages,
       sort_by: sort_by,
       sort_dir: sort_dir,
       filter_job_type: filter_job_type,
       filter_status: filter_status,
       filter_priority: filter_priority,
       filter_model: filter_model,
       view_mode: if(queue_only, do: "queue", else: "all"),
       stats: stats,
       semaphore: semaphore,
       paused: paused,
       available_models: models,
       available_job_types: job_types
     )}
  end

  @impl true
  def handle_event("toggle-auto-reload", _params, socket) do
    new_state = !socket.assigns.auto_reload
    socket = assign(socket, auto_reload: new_state)
    if new_state, do: send(self(), :auto_reload)
    {:noreply, socket}
  end

  @impl true
  def handle_event("pause-queue", _params, socket) do
    AI.pause_queue()
    {:noreply, assign(socket, paused: true)}
  end

  @impl true
  def handle_event("resume-queue", _params, socket) do
    AI.resume_queue()
    {:noreply, assign(socket, paused: false)}
  end

  @impl true
  def handle_event("cancel-job", %{"id" => job_id}, socket) do
    case AI.cancel(job_id) do
      {:ok, _} -> {:noreply, reload_jobs(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Cannot cancel this job."))}
    end
  end

  @impl true
  def handle_event("retry-job", %{"id" => job_id}, socket) do
    case AI.retry(job_id) do
      {:ok, _} -> {:noreply, reload_jobs(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, gettext("Cannot retry this job."))}
    end
  end

  @impl true
  def handle_event("force-cancel-job", %{"id" => job_id}, socket) do
    case AI.force_cancel(job_id) do
      {:ok, _} ->
        {:noreply, reload_jobs(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Cannot cancel this job."))}
    end
  end

  @impl true
  def handle_event("force-restart-job", %{"id" => job_id}, socket) do
    case AI.force_restart(job_id) do
      {:ok, _} ->
        {:noreply, reload_jobs(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Cannot restart this job."))}
    end
  end

  @impl true
  def handle_event("reprioritize", %{"id" => job_id, "priority" => priority}, socket) do
    case AI.reprioritize(job_id, String.to_integer(priority)) do
      {:ok, _} ->
        {:noreply, reload_jobs(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Cannot reprioritize this job."))}
    end
  end

  @impl true
  def handle_event("filter-job-type", %{"job_type" => type}, socket) do
    filter = if type == "", do: nil, else: type
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_job_type: filter))}
  end

  @impl true
  def handle_event("filter-status", %{"status" => status}, socket) do
    filter = if status == "", do: nil, else: status
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_status: filter))}
  end

  @impl true
  def handle_event("filter-model", %{"model" => model}, socket) do
    filter = if model == "", do: nil, else: model
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_model: filter))}
  end

  @impl true
  def handle_event("switch-view", %{"view" => view}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, view_mode: view))}
  end

  @impl true
  def handle_event("show-detail", %{"id" => job_id}, socket) do
    job = AI.get_job(job_id)
    {:noreply, assign(socket, detail_job: job, detail_tab: "result")}
  end

  @impl true
  def handle_event("close-detail", _params, socket) do
    {:noreply, assign(socket, detail_job: nil)}
  end

  @impl true
  def handle_event("detail-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, detail_tab: tab)}
  end

  @impl true
  def handle_event("enlarge-photo", %{"id" => photo_id}, socket) do
    photo = Photos.get_photo(photo_id)
    {:noreply, assign(socket, enlarged_photo: photo)}
  end

  @impl true
  def handle_event("close-photo", _params, socket) do
    {:noreply, assign(socket, enlarged_photo: nil)}
  end

  @impl true
  def handle_event("show-bulk-retry", %{"range" => range}, socket) do
    since = bulk_retry_since(range)
    count = AI.count_failed_since(since)

    {:noreply,
     assign(socket,
       show_bulk_retry_modal: true,
       bulk_retry_range: range,
       bulk_retry_count: count
     )}
  end

  @impl true
  def handle_event("confirm-bulk-retry", _params, socket) do
    since = bulk_retry_since(socket.assigns.bulk_retry_range)
    {count, _} = AI.retry_failed_since(since)

    socket =
      socket
      |> assign(show_bulk_retry_modal: false, bulk_retry_range: nil, bulk_retry_count: 0)
      |> put_flash(
        :info,
        ngettext(
          "%{count} failed job reset to pending.",
          "%{count} failed jobs reset to pending.",
          count,
          count: count
        )
      )
      |> reload_jobs()

    {:noreply, socket}
  end

  @impl true
  def handle_event("close-bulk-retry-modal", _params, socket) do
    {:noreply,
     assign(socket, show_bulk_retry_modal: false, bulk_retry_range: nil, bulk_retry_count: 0)}
  end

  @impl true
  def handle_event("show-regenerate-modal", _params, socket) do
    count = Photos.count_approved_photos()
    {:noreply, assign(socket, show_regenerate_modal: true, regenerate_count: count)}
  end

  @impl true
  def handle_event("confirm-regenerate", _params, socket) do
    requester_id = socket.assigns.current_scope.user.id
    {enqueued, skipped} = AI.enqueue_all_photo_descriptions(requester_id: requester_id)

    socket =
      socket
      |> assign(show_regenerate_modal: false, regenerate_count: 0)
      |> put_flash(
        :info,
        gettext(
          "Regeneration started: %{enqueued} jobs enqueued, %{skipped} skipped (already queued).",
          enqueued: enqueued,
          skipped: skipped
        )
      )
      |> reload_jobs()

    {:noreply, socket}
  end

  @impl true
  def handle_event("close-regenerate-modal", _params, socket) do
    {:noreply, assign(socket, show_regenerate_modal: false, regenerate_count: 0)}
  end

  @impl true
  def handle_info(:auto_reload, socket) do
    if socket.assigns.auto_reload do
      Process.send_after(self(), :auto_reload, 2000)
      {:noreply, reload_jobs(socket)}
    else
      {:noreply, socket}
    end
  end

  defp reload_jobs(socket) do
    result =
      AI.list_jobs(
        page: socket.assigns.page,
        per_page: socket.assigns.per_page,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir,
        filter_job_type: socket.assigns.filter_job_type,
        filter_status: socket.assigns.filter_status,
        filter_priority: socket.assigns.filter_priority,
        filter_model: socket.assigns.filter_model,
        queue_only: socket.assigns.view_mode == "queue"
      )

    assign(socket,
      jobs: result.entries,
      total_count: result.total_count,
      total_pages: result.total_pages,
      stats: AI.queue_stats(),
      semaphore: safe_semaphore_status(),
      paused: AI.queue_paused?()
    )
  end

  # --- Helpers ---

  defp parse_sort_by("priority"), do: :priority
  defp parse_sort_by("duration_ms"), do: :duration_ms
  defp parse_sort_by("model"), do: :model
  defp parse_sort_by("status"), do: :status
  defp parse_sort_by("job_type"), do: :job_type
  defp parse_sort_by("inserted_at"), do: :inserted_at
  defp parse_sort_by(_), do: :inserted_at

  defp build_path(socket, overrides) do
    params =
      %{
        page: Keyword.get(overrides, :page, socket.assigns.page),
        per_page: Keyword.get(overrides, :per_page, socket.assigns.per_page),
        sort_by: Keyword.get(overrides, :sort_by, socket.assigns.sort_by),
        sort_dir: Keyword.get(overrides, :sort_dir, socket.assigns.sort_dir),
        view: Keyword.get(overrides, :view_mode, socket.assigns.view_mode)
      }
      |> maybe_put(
        :job_type,
        Keyword.get(overrides, :filter_job_type, socket.assigns.filter_job_type)
      )
      |> maybe_put(:status, Keyword.get(overrides, :filter_status, socket.assigns.filter_status))
      |> maybe_put(
        :priority,
        Keyword.get(overrides, :filter_priority, socket.assigns.filter_priority)
      )
      |> maybe_put(:model, Keyword.get(overrides, :filter_model, socket.assigns.filter_model))

    ~p"/admin/logs/ai?#{params}"
  end

  defp safe_semaphore_status do
    Semaphore.status()
  rescue
    _ -> %{active: 0, max: 0, waiting: 0}
  end

  defp bulk_retry_since("1h"), do: DateTime.utc_now() |> DateTime.add(-1, :hour)
  defp bulk_retry_since("2h"), do: DateTime.utc_now() |> DateTime.add(-2, :hour)

  defp bulk_retry_since("today") do
    Date.utc_today()
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp bulk_retry_since(_), do: DateTime.utc_now() |> DateTime.add(-1, :hour)

  defp bulk_retry_range_label("1h"), do: gettext("last hour")
  defp bulk_retry_range_label("2h"), do: gettext("last 2 hours")
  defp bulk_retry_range_label("today"), do: gettext("today")
  defp bulk_retry_range_label(_), do: ""

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
            <li>{gettext("AI Jobs")}</li>
          </ul>
        </div>

        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("AI Jobs")}</h1>
          <span class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} job",
              "%{count} jobs",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Status Bar --%>
        <div class="flex flex-wrap gap-3 mb-6">
          <div class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2">
            <span class="text-sm text-base-content/60">{gettext("Pending")}</span>
            <span class={[
              "badge badge-sm font-mono",
              if(@stats.pending > 0, do: "badge-warning", else: "badge-ghost")
            ]}>
              {@stats.pending}
            </span>
          </div>

          <div class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2">
            <span class="text-sm text-base-content/60">{gettext("Running")}</span>
            <span class={[
              "badge badge-sm font-mono",
              if(@stats.running > 0, do: "badge-info", else: "badge-ghost")
            ]}>
              {@stats.running}
            </span>
          </div>

          <div class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2">
            <span class="text-sm text-base-content/60">{gettext("Failed")}</span>
            <span class={[
              "badge badge-sm font-mono",
              if(@stats.failed > 0, do: "badge-error", else: "badge-ghost")
            ]}>
              {@stats.failed}
            </span>
          </div>

          <div class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2">
            <span class="text-sm text-base-content/60">{gettext("Slots")}</span>
            <span class="badge badge-sm badge-primary font-mono">
              {@semaphore.active}/{@semaphore.max}
            </span>
          </div>

          <%!-- Pause/Resume Button --%>
          <%= if @paused do %>
            <button
              class="btn btn-sm btn-success gap-1"
              phx-click="resume-queue"
            >
              <.icon name="hero-play-solid" class="h-4 w-4" />
              {gettext("Resume")}
            </button>
          <% else %>
            <button
              class="btn btn-sm btn-warning gap-1"
              phx-click="pause-queue"
            >
              <.icon name="hero-pause-solid" class="h-4 w-4" />
              {gettext("Pause")}
            </button>
          <% end %>

          <label class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2 cursor-pointer">
            <span class="text-sm text-base-content/60">{gettext("Auto-reload")}</span>
            <input
              type="checkbox"
              class="toggle toggle-sm toggle-primary"
              checked={@auto_reload}
              phx-click="toggle-auto-reload"
            />
          </label>
        </div>

        <%!-- Paused Banner --%>
        <%= if @paused do %>
          <div class="alert alert-warning mb-4">
            <.icon name="hero-pause-circle" class="h-5 w-5" />
            <span>{gettext("AI queue is paused. No new jobs will be dispatched.")}</span>
          </div>
        <% end %>

        <%!-- Bulk Actions --%>
        <div class="flex items-center gap-2 mb-4">
          <div class="dropdown">
            <div
              tabindex="0"
              role="button"
              class="btn btn-sm btn-outline btn-error gap-1"
            >
              <.icon name="hero-arrow-path" class="h-4 w-4" />
              {gettext("Retry All Failed")}
              <.icon name="hero-chevron-down" class="h-3 w-3" />
            </div>
            <ul
              tabindex="0"
              class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-48"
            >
              <li>
                <button phx-click="show-bulk-retry" phx-value-range="1h">
                  {gettext("Last hour")}
                </button>
              </li>
              <li>
                <button phx-click="show-bulk-retry" phx-value-range="2h">
                  {gettext("Last 2 hours")}
                </button>
              </li>
              <li>
                <button phx-click="show-bulk-retry" phx-value-range="today">
                  {gettext("Today")}
                </button>
              </li>
            </ul>
          </div>

          <button
            class="btn btn-sm btn-outline btn-accent gap-1"
            phx-click="show-regenerate-modal"
          >
            <.icon name="hero-sparkles" class="h-4 w-4" />
            {gettext("Regenerate Descriptions")}
          </button>
        </div>

        <%!-- Bulk Retry Confirmation Modal --%>
        <%= if @show_bulk_retry_modal do %>
          <div class="modal modal-open">
            <div class="modal-box">
              <h3 class="text-lg font-bold">{gettext("Retry Failed Jobs")}</h3>
              <p class="py-4">
                {ngettext(
                  "Are you sure you want to retry %{count} failed job from the %{range}?",
                  "Are you sure you want to retry %{count} failed jobs from the %{range}?",
                  @bulk_retry_count,
                  count: @bulk_retry_count,
                  range: bulk_retry_range_label(@bulk_retry_range)
                )}
              </p>
              <div class="modal-action">
                <button class="btn" phx-click="close-bulk-retry-modal">
                  {gettext("Cancel")}
                </button>
                <button class="btn btn-error" phx-click="confirm-bulk-retry">
                  <.icon name="hero-arrow-path" class="h-4 w-4" />
                  {gettext("Retry")}
                </button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close-bulk-retry-modal"></div>
          </div>
        <% end %>

        <%!-- Regenerate Descriptions Confirmation Modal --%>
        <%= if @show_regenerate_modal do %>
          <div class="modal modal-open">
            <div class="modal-box">
              <h3 class="text-lg font-bold">{gettext("Regenerate All Descriptions")}</h3>
              <p class="py-4">
                {ngettext(
                  "This will enqueue description jobs for %{count} approved photo at background priority. Photos with pending jobs will be skipped.",
                  "This will enqueue description jobs for %{count} approved photos at background priority. Photos with pending jobs will be skipped.",
                  @regenerate_count,
                  count: @regenerate_count
                )}
              </p>
              <div class="modal-action">
                <button class="btn" phx-click="close-regenerate-modal">
                  {gettext("Cancel")}
                </button>
                <button class="btn btn-accent" phx-click="confirm-regenerate">
                  <.icon name="hero-sparkles" class="h-4 w-4" />
                  {gettext("Regenerate")}
                </button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close-regenerate-modal"></div>
          </div>
        <% end %>

        <%!-- View Toggle --%>
        <div class="tabs tabs-boxed mb-4 w-fit">
          <button
            phx-click="switch-view"
            phx-value-view="all"
            class={["tab", if(@view_mode == "all", do: "tab-active")]}
          >
            {gettext("All Jobs")}
          </button>
          <button
            phx-click="switch-view"
            phx-value-view="queue"
            class={["tab", if(@view_mode == "queue", do: "tab-active")]}
          >
            {gettext("Queue")}
          </button>
        </div>

        <%!-- Filters --%>
        <div class="flex flex-wrap items-end gap-4 mb-4">
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Job Type")}</span>
            </div>
            <select
              class="select select-bordered select-sm"
              phx-change="filter-job-type"
              name="job_type"
            >
              <option value="" selected={is_nil(@filter_job_type)}>{gettext("All")}</option>
              <%= for type <- @available_job_types do %>
                <option value={type} selected={@filter_job_type == type}>
                  {format_job_type(type)}
                </option>
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
              <option value="pending" selected={@filter_status == "pending"}>
                {gettext("Pending")}
              </option>
              <option value="running" selected={@filter_status == "running"}>
                {gettext("Running")}
              </option>
              <option value="completed" selected={@filter_status == "completed"}>
                {gettext("Completed")}
              </option>
              <option value="failed" selected={@filter_status == "failed"}>
                {gettext("Failed")}
              </option>
              <option value="cancelled" selected={@filter_status == "cancelled"}>
                {gettext("Cancelled")}
              </option>
            </select>
          </label>

          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Model")}</span>
            </div>
            <select
              class="select select-bordered select-sm"
              phx-change="filter-model"
              name="model"
            >
              <option value="" selected={is_nil(@filter_model)}>{gettext("All")}</option>
              <%= for model <- @available_models do %>
                <option value={model} selected={@filter_model == model}>{model}</option>
              <% end %>
            </select>
          </label>

          <.per_page_selector per_page={@per_page} sizes={[50, 100, 150, 500]} />
        </div>

        <%!-- Jobs Table --%>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>{gettext("Subject")}</th>
                <th
                  class="cursor-pointer hover:bg-base-200"
                  phx-click="sort"
                  phx-value-column="job_type"
                >
                  {gettext("Type")}
                  <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:job_type} />
                </th>
                <th
                  class="cursor-pointer hover:bg-base-200"
                  phx-click="sort"
                  phx-value-column="priority"
                >
                  {gettext("Priority")}
                  <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:priority} />
                </th>
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
                  phx-value-column="model"
                >
                  {gettext("Model")}
                  <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:model} />
                </th>
                <th>{gettext("Server")}</th>
                <th
                  class="cursor-pointer hover:bg-base-200"
                  phx-click="sort"
                  phx-value-column="duration_ms"
                >
                  {gettext("Duration")}
                  <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:duration_ms} />
                </th>
                <th>{gettext("Attempt")}</th>
                <th
                  class="cursor-pointer hover:bg-base-200"
                  phx-click="sort"
                  phx-value-column="inserted_at"
                >
                  {gettext("Time")}
                  <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:inserted_at} />
                </th>
                <th>{gettext("Actions")}</th>
              </tr>
            </thead>
            <tbody>
              <%= for job <- @jobs do %>
                <tr class={row_class(job.status)}>
                  <td>
                    <.subject_cell job={job} />
                  </td>
                  <td>
                    <span class={["badge badge-sm", job_type_badge_class(job.job_type)]}>
                      {format_job_type(job.job_type)}
                    </span>
                  </td>
                  <td>
                    <span class={["badge badge-sm", priority_badge_class(job.priority)]}>
                      {format_priority(job.priority)}
                    </span>
                  </td>
                  <td>
                    <span class={["badge badge-sm", status_badge_class(job.status)]}>
                      {job.status}
                    </span>
                    <%= if job.error do %>
                      <% {label, badge_class} = classify_error(job.error) %>
                      <span
                        class={["badge badge-xs ml-1 cursor-help", badge_class]}
                        title={job.error}
                      >
                        {label}
                      </span>
                    <% end %>
                  </td>
                  <td>
                    <span class="badge badge-sm badge-ghost font-mono">{job.model || "-"}</span>
                  </td>
                  <td>
                    <span class="text-xs font-mono text-base-content/60">
                      {extract_hostname(job.server_url)}
                    </span>
                  </td>
                  <td>
                    <span class="font-mono text-sm">{format_duration(job.duration_ms)}</span>
                  </td>
                  <td>
                    <span class="text-sm font-mono">
                      {job.attempt}/{job.max_attempts}
                    </span>
                  </td>
                  <td>
                    <span class="text-xs" title={format_datetime(job.inserted_at)}>
                      {relative_time(job.inserted_at)}
                    </span>
                  </td>
                  <td>
                    <.action_buttons job={job} />
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Job Type Legend --%>
        <div class="flex flex-wrap gap-4 mt-4 mb-4 p-3 bg-base-200 rounded-lg text-sm">
          <span class="font-semibold text-base-content/70">{gettext("Job Types")}:</span>
          <div class="flex items-center gap-1">
            <span class="badge badge-xs badge-primary"></span>
            <span class="font-medium">{gettext("Classification")}</span>
            <span class="text-base-content/50">
              &mdash; {gettext("Checks if photo is family-friendly, detects faces, counts people")}
            </span>
          </div>
          <div class="flex items-center gap-1">
            <span class="badge badge-xs badge-secondary"></span>
            <span class="font-medium">{gettext("Gender Guess")}</span>
            <span class="text-base-content/50">
              &mdash; {gettext("Guesses gender from a first name (used for discovery)")}
            </span>
          </div>
          <div class="flex items-center gap-1">
            <span class="badge badge-xs badge-accent"></span>
            <span class="font-medium">{gettext("Description")}</span>
            <span class="text-base-content/50">
              &mdash; {gettext("Generates an AI text description of a photo")}
            </span>
          </div>
        </div>

        <%!-- Pagination --%>
        <.pagination page={@page} total_pages={@total_pages} />

        <%!-- Detail Modal --%>
        <%= if @detail_job do %>
          <div class="modal modal-open">
            <div class="modal-box max-w-3xl">
              <button
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-detail"
              >
                &times;
              </button>
              <h3 class="text-lg font-bold mb-4">
                {gettext("Job Details")}
                <span class="badge badge-sm badge-ghost font-mono ml-2">
                  {String.slice(@detail_job.id, 0, 8)}
                </span>
              </h3>

              <%!-- Tabs --%>
              <div role="tablist" class="tabs tabs-bordered mb-4">
                <%= if @detail_job.result do %>
                  <button
                    role="tab"
                    class={["tab", if(@detail_tab == "result", do: "tab-active")]}
                    phx-click="detail-tab"
                    phx-value-tab="result"
                  >
                    {gettext("Result")}
                  </button>
                <% end %>
                <%= if @detail_job.prompt do %>
                  <button
                    role="tab"
                    class={["tab", if(@detail_tab == "prompt", do: "tab-active")]}
                    phx-click="detail-tab"
                    phx-value-tab="prompt"
                  >
                    {gettext("Prompt")}
                  </button>
                <% end %>
                <%= if @detail_job.raw_response do %>
                  <button
                    role="tab"
                    class={["tab", if(@detail_tab == "response", do: "tab-active")]}
                    phx-click="detail-tab"
                    phx-value-tab="response"
                  >
                    {gettext("Response")}
                  </button>
                <% end %>
                <%= if @detail_job.error do %>
                  <button
                    role="tab"
                    class={["tab", if(@detail_tab == "error", do: "tab-active")]}
                    phx-click="detail-tab"
                    phx-value-tab="error"
                  >
                    {gettext("Error")}
                  </button>
                <% end %>
              </div>

              <%!-- Tab Content --%>
              <div class="bg-base-200 rounded-lg p-4 max-h-96 overflow-auto">
                <%= cond do %>
                  <% @detail_tab == "result" && @detail_job.result -> %>
                    <pre class="text-xs font-mono whitespace-pre-wrap break-words">{format_json(@detail_job.result)}</pre>
                  <% @detail_tab == "prompt" && @detail_job.prompt -> %>
                    <pre class="text-xs font-mono whitespace-pre-wrap break-words">{@detail_job.prompt}</pre>
                  <% @detail_tab == "response" && @detail_job.raw_response -> %>
                    <pre class="text-xs font-mono whitespace-pre-wrap break-words">{@detail_job.raw_response}</pre>
                  <% @detail_tab == "error" && @detail_job.error -> %>
                    <pre class="text-xs font-mono whitespace-pre-wrap break-words text-error">{@detail_job.error}</pre>
                  <% true -> %>
                    <p class="text-base-content/50 text-sm">{gettext("No data available.")}</p>
                <% end %>
              </div>

              <%!-- Meta info --%>
              <div class="flex flex-wrap gap-4 mt-4 text-xs text-base-content/60">
                <span>
                  <span class="font-semibold">{gettext("Server")}:</span>
                  {extract_hostname(@detail_job.server_url)}
                </span>
                <span>
                  <span class="font-semibold">{gettext("Model")}:</span> {@detail_job.model || "-"}
                </span>
                <span>
                  <span class="font-semibold">{gettext("Duration")}:</span>
                  {format_duration(@detail_job.duration_ms)}
                </span>
                <span>
                  <span class="font-semibold">{gettext("Attempt")}:</span>
                  {@detail_job.attempt}/{@detail_job.max_attempts}
                </span>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close-detail"></div>
          </div>
        <% end %>

        <%!-- Photo Enlargement Modal --%>
        <%= if @enlarged_photo do %>
          <div class="modal modal-open" phx-click="close-photo">
            <div class="modal-box max-w-2xl p-2">
              <button
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2 z-10"
                phx-click="close-photo"
              >
                &times;
              </button>
              <img
                src={Photos.signed_url(@enlarged_photo, :normal)}
                class="w-full h-auto rounded"
              />
              <div class="text-center mt-2 flex justify-center gap-4">
                <.link
                  navigate={~p"/admin/photos/#{@enlarged_photo.id}"}
                  class="link link-primary text-sm"
                >
                  {gettext("View photo details")}
                </.link>
                <.link
                  navigate={~p"/admin/photos/#{@enlarged_photo.id}/history"}
                  class="link link-primary text-sm"
                >
                  {gettext("View photo history")}
                </.link>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close-photo"></div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # --- Sub-components ---

  defp subject_cell(assigns) do
    ~H"""
    <%= cond do %>
      <% @job.subject_type == "Photo" && @job.subject_id -> %>
        <.photo_subject photo_id={@job.subject_id} />
      <% @job.job_type == "gender_guess" -> %>
        <span class="text-sm">{@job.params["name"]}</span>
      <% true -> %>
        <span class="text-xs text-base-content/40">-</span>
    <% end %>
    """
  end

  defp photo_subject(assigns) do
    photo = Photos.get_photo(assigns.photo_id)
    assigns = assign(assigns, :photo, photo)

    ~H"""
    <%= if @photo do %>
      <button phx-click="enlarge-photo" phx-value-id={@photo.id} class="block cursor-zoom-in">
        <img
          src={Photos.signed_url(@photo, :thumbnail)}
          class="w-10 h-10 object-cover rounded"
          loading="lazy"
        />
      </button>
    <% else %>
      <span class="text-xs text-base-content/40">{String.slice(@photo_id, 0, 8)}...</span>
    <% end %>
    """
  end

  defp action_buttons(assigns) do
    ~H"""
    <div class="flex gap-1">
      <%= if @job.status in ~w(completed failed cancelled) do %>
        <button
          class="btn btn-xs btn-outline btn-info"
          phx-click="show-detail"
          phx-value-id={@job.id}
          title={gettext("Details")}
        >
          <.icon name="hero-eye" class="h-3 w-3" />
        </button>
      <% end %>

      <%= if @job.status in ~w(failed cancelled) do %>
        <button
          class="btn btn-xs btn-outline btn-success"
          phx-click="retry-job"
          phx-value-id={@job.id}
          title={gettext("Retry")}
        >
          <.icon name="hero-arrow-path" class="h-3 w-3" />
        </button>
      <% end %>

      <%= if @job.status in ~w(pending scheduled paused) do %>
        <button
          class="btn btn-xs btn-outline btn-error"
          phx-click="cancel-job"
          phx-value-id={@job.id}
          title={gettext("Cancel")}
        >
          <.icon name="hero-x-mark" class="h-3 w-3" />
        </button>
      <% end %>

      <%= if @job.status == "running" do %>
        <button
          class="btn btn-xs btn-outline btn-info"
          phx-click="show-detail"
          phx-value-id={@job.id}
          title={gettext("Details")}
        >
          <.icon name="hero-eye" class="h-3 w-3" />
        </button>
        <button
          class="btn btn-xs btn-warning"
          phx-click="force-restart-job"
          phx-value-id={@job.id}
          data-confirm={gettext("Restart this running job?")}
          title={gettext("Restart")}
        >
          <.icon name="hero-arrow-path" class="h-3 w-3" />
        </button>
        <button
          class="btn btn-xs btn-error"
          phx-click="force-cancel-job"
          phx-value-id={@job.id}
          data-confirm={gettext("Cancel this running job?")}
          title={gettext("Cancel")}
        >
          <.icon name="hero-x-mark" class="h-3 w-3" />
        </button>
      <% end %>

      <%= if @job.status in ~w(pending scheduled) do %>
        <div class="dropdown dropdown-end">
          <div
            tabindex="0"
            role="button"
            class="btn btn-xs btn-outline btn-primary"
            title={gettext("Reprioritize")}
          >
            <.icon name="hero-arrows-up-down" class="h-3 w-3" />
          </div>
          <ul tabindex="0" class="dropdown-content z-[1] menu p-1 shadow bg-base-100 rounded-box w-32">
            <%= for {label, val} <- [{"Critical", 1}, {"High", 2}, {"Normal", 3}, {"Low", 4}, {"Background", 5}] do %>
              <li>
                <button
                  phx-click="reprioritize"
                  phx-value-id={@job.id}
                  phx-value-priority={val}
                  class={if(@job.priority == val, do: "active")}
                >
                  {label}
                </button>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end

  # --- Error classification ---

  @error_patterns [
    {["timeout", ":timeout"], "GPU Timeout", "badge-warning"},
    {[":econnrefused", "econnrefused"], "GPU Offline", "badge-error"},
    {["all_instances_unavailable"], "All GPUs Down", "badge-error"},
    {["total_timeout_exceeded"], "Total Timeout", "badge-warning"},
    {["Semaphore timeout"], "Queue Full", "badge-warning"},
    {["http_error, 503", "http_error, 500"], "GPU Error", "badge-error"},
    {["runner has unexpectedly stopped"], "GPU Crash", "badge-error"},
    {["thumbnail_read_failed"], "File Error", "badge-ghost"}
  ]

  defp classify_error(nil), do: nil

  defp classify_error(error) do
    case Enum.find(@error_patterns, fn {patterns, _, _} ->
           Enum.any?(patterns, &String.contains?(error, &1))
         end) do
      {_, label, badge} -> {error_label(label), badge}
      nil -> {error_label("Error"), "badge-error"}
    end
  end

  defp error_label("GPU Timeout"), do: gettext("GPU Timeout")
  defp error_label("GPU Offline"), do: gettext("GPU Offline")
  defp error_label("All GPUs Down"), do: gettext("All GPUs Down")
  defp error_label("Total Timeout"), do: gettext("Total Timeout")
  defp error_label("Queue Full"), do: gettext("Queue Full")
  defp error_label("GPU Error"), do: gettext("GPU Error")
  defp error_label("GPU Crash"), do: gettext("GPU Crash")
  defp error_label("File Error"), do: gettext("File Error")
  defp error_label("Error"), do: gettext("Error")

  # --- Formatting helpers ---

  defp extract_hostname(nil), do: "-"

  defp extract_hostname(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end

  defp format_json(map) when is_map(map), do: Jason.encode!(map, pretty: true)
  defp format_json(other), do: inspect(other)

  defp format_job_type("photo_classification"), do: "Classification"
  defp format_job_type("gender_guess"), do: "Gender Guess"
  defp format_job_type("photo_description"), do: "Description"
  defp format_job_type(other), do: other

  defp format_priority(1), do: "Critical"
  defp format_priority(2), do: "High"
  defp format_priority(3), do: "Normal"
  defp format_priority(4), do: "Low"
  defp format_priority(5), do: "Background"
  defp format_priority(_), do: "-"

  defp format_duration(nil), do: "-"
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) do
    seconds = ms / 1000
    :erlang.float_to_binary(seconds, decimals: 1) <> "s"
  end

  defp row_class("failed"), do: "bg-error/5"
  defp row_class("running"), do: "bg-info/5"
  defp row_class("cancelled"), do: "bg-base-200/50"
  defp row_class(_), do: nil

  defp status_badge_class("pending"), do: "badge-warning"
  defp status_badge_class("scheduled"), do: "badge-warning"
  defp status_badge_class("running"), do: "badge-info"
  defp status_badge_class("completed"), do: "badge-success"
  defp status_badge_class("failed"), do: "badge-error"
  defp status_badge_class("cancelled"), do: "badge-ghost"
  defp status_badge_class("paused"), do: "badge-neutral"
  defp status_badge_class(_), do: "badge-ghost"

  defp job_type_badge_class("photo_classification"), do: "badge-primary"
  defp job_type_badge_class("gender_guess"), do: "badge-secondary"
  defp job_type_badge_class("photo_description"), do: "badge-accent"
  defp job_type_badge_class(_), do: "badge-ghost"

  defp priority_badge_class(1), do: "badge-error"
  defp priority_badge_class(2), do: "badge-warning"
  defp priority_badge_class(3), do: "badge-info"
  defp priority_badge_class(4), do: "badge-ghost"
  defp priority_badge_class(5), do: "badge-ghost"
  defp priority_badge_class(_), do: "badge-ghost"
end
