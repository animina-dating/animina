defmodule AniminaWeb.Admin.OllamaLogsLive do
  use AniminaWeb, :live_view

  alias Animina.FeatureFlags
  alias Animina.Photos
  alias Animina.Photos.OllamaClient
  alias Animina.Photos.PhotoFeedback
  alias Animina.Photos.PhotoProcessor
  alias AniminaWeb.Layouts

  import AniminaWeb.Helpers.AdminHelpers,
    only: [parse_int: 2, format_datetime: 1]

  @default_per_page 50
  @available_models ["qwen3-vl:2b", "qwen3-vl:4b", "qwen3-vl:8b"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Ollama Logs"),
       view_mode: "all",
       rerunning: MapSet.new(),
       auto_reload: false
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    sort_by = parse_sort_by(params["sort_by"])
    sort_dir = parse_sort_dir(params["sort_dir"])
    filter_model = params["model"]
    filter_status = params["status"]
    view_mode = params["view"] || "all"

    result =
      Photos.list_ollama_logs(
        page: page,
        per_page: per_page,
        sort_by: sort_by,
        sort_dir: sort_dir,
        filter_model: filter_model,
        filter_status: filter_status
      )

    models = Photos.distinct_ollama_models()

    grouped_data =
      if view_mode == "by_photo" do
        group_logs_by_photo(result.entries)
      else
        nil
      end

    queue_count = Photos.count_ollama_queue()
    current_model = Photos.select_ollama_model()
    adaptive_enabled = FeatureFlags.enabled?(:ollama_adaptive_model)

    {:noreply,
     assign(socket,
       logs: result.entries,
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages,
       sort_by: sort_by,
       sort_dir: sort_dir,
       filter_model: filter_model,
       filter_status: filter_status,
       available_models: models,
       view_mode: view_mode,
       grouped_data: grouped_data,
       queue_count: queue_count,
       current_model: current_model,
       adaptive_enabled: adaptive_enabled
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
  def handle_event("change-per-page", %{"per_page" => per_page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, per_page: per_page))}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: page))}
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
  def handle_event("filter-model", %{"model" => model}, socket) do
    filter = if model == "", do: nil, else: model
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_model: filter))}
  end

  @impl true
  def handle_event("filter-status", %{"status" => status}, socket) do
    filter = if status == "", do: nil, else: status
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, filter_status: filter))}
  end

  @impl true
  def handle_event("switch-view", %{"view" => view}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, page: 1, view_mode: view))}
  end

  @impl true
  def handle_event(
        "rerun_with_model",
        %{"log_id" => log_id, "model" => model},
        socket
      ) do
    log = Photos.get_ollama_log(log_id)
    admin = socket.assigns.current_scope.user

    if log && log.photo do
      rerunning = MapSet.put(socket.assigns.rerunning, log_id)
      socket = assign(socket, rerunning: rerunning)

      start_rerun_task(log, log_id, admin.id, model: model)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, gettext("Log entry or photo not found."))}
    end
  end

  @impl true
  def handle_event(
        "rerun_on_server",
        %{"log_id" => log_id, "server" => server_url},
        socket
      ) do
    log = Photos.get_ollama_log(log_id)
    admin = socket.assigns.current_scope.user

    if log && log.photo do
      rerunning = MapSet.put(socket.assigns.rerunning, log_id)
      socket = assign(socket, rerunning: rerunning)

      start_rerun_task(log, log_id, admin.id, target_server: server_url)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, gettext("Log entry or photo not found."))}
    end
  end

  @impl true
  def handle_info(:auto_reload, socket) do
    if socket.assigns.auto_reload do
      Process.send_after(self(), :auto_reload, 1000)
      {:noreply, reload_logs(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:rerun_complete, log_id, result}, socket) do
    rerunning = MapSet.delete(socket.assigns.rerunning, log_id)
    socket = assign(socket, rerunning: rerunning)

    case result do
      {:ok, _, _} ->
        {:noreply, reload_logs(socket)}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Re-run failed: %{reason}", reason: inspect(reason))
         )}
    end
  end

  defp reload_logs(socket) do
    result =
      Photos.list_ollama_logs(
        page: socket.assigns.page,
        per_page: socket.assigns.per_page,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir,
        filter_model: socket.assigns.filter_model,
        filter_status: socket.assigns.filter_status
      )

    grouped_data =
      if socket.assigns.view_mode == "by_photo" do
        group_logs_by_photo(result.entries)
      else
        nil
      end

    assign(socket,
      logs: result.entries,
      total_count: result.total_count,
      total_pages: result.total_pages,
      grouped_data: grouped_data,
      queue_count: Photos.count_ollama_queue(),
      current_model: Photos.select_ollama_model(),
      adaptive_enabled: FeatureFlags.enabled?(:ollama_adaptive_model)
    )
  end

  # --- Helpers ---

  defp parse_sort_by("duration_ms"), do: :duration_ms
  defp parse_sort_by("model"), do: :model
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
        sort_dir: Keyword.get(overrides, :sort_dir, socket.assigns.sort_dir),
        view: Keyword.get(overrides, :view_mode, socket.assigns.view_mode)
      }
      |> maybe_put(:model, Keyword.get(overrides, :filter_model, socket.assigns.filter_model))
      |> maybe_put(:status, Keyword.get(overrides, :filter_status, socket.assigns.filter_status))

    ~p"/admin/logs/ollama?#{params}"
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp group_logs_by_photo(logs) do
    logs
    |> Enum.filter(&(&1.photo_id != nil))
    |> Enum.group_by(& &1.photo_id)
    |> Enum.map(fn {photo_id, entries} ->
      sorted = Enum.sort_by(entries, & &1.duration_ms)
      first = hd(sorted)
      agreement = compute_agreement(entries)

      %{
        photo_id: photo_id,
        photo: first.photo,
        owner: first.owner,
        entries: sorted,
        count: length(entries),
        agreement: agreement
      }
    end)
    |> Enum.sort_by(fn g -> hd(g.entries).inserted_at end, {:desc, DateTime})
  end

  defp compute_agreement(entries) do
    results =
      entries
      |> Enum.filter(&(&1.status == "success" && &1.result != nil))
      |> Enum.map(fn entry ->
        case avatar_verdict(entry) do
          :approved -> :approved
          {:rejected, _} -> :rejected
        end
      end)

    case results do
      [] ->
        :unknown

      [_] ->
        :single

      _ ->
        if Enum.all?(results, &(&1 == hd(results))), do: :agree, else: :disagree
    end
  end

  defp avatar_verdict(log) when log.status != "success" or is_nil(log.result), do: nil

  defp avatar_verdict(log) do
    parsed = PhotoProcessor.parse_ollama_response(log.result)

    case PhotoFeedback.analyze_avatar(parsed) do
      {:ok, :approved} -> :approved
      {:error, _violation, message} -> {:rejected, message}
    end
  end

  defp moodboard_verdict(log) when log.status != "success" or is_nil(log.result), do: nil

  defp moodboard_verdict(log) do
    parsed = PhotoProcessor.parse_ollama_response(log.result)

    case PhotoFeedback.analyze_moodboard(parsed) do
      {:ok, :approved} -> :approved
      {:error, _violation, message} -> {:rejected, message}
    end
  end

  defp start_rerun_task(log, log_id, requester_id, opts) do
    pid = self()

    Task.Supervisor.start_child(Animina.Photos.TaskSupervisor, fn ->
      result = run_ollama_rerun(log, requester_id, opts)
      send(pid, {:rerun_complete, log_id, result})
    end)
  end

  defp run_ollama_rerun(log, requester_id, opts) do
    thumbnail_path = Photos.processed_path(log.photo, :thumbnail)

    if File.exists?(thumbnail_path) do
      image_data = File.read!(thumbnail_path) |> Base.encode64()
      prompt = log.prompt || PhotoProcessor.ollama_prompt()
      owner_id = if log.photo.owner_type == "User", do: log.photo.owner_id, else: nil

      completion_opts =
        [
          model: Keyword.get(opts, :model, log.model),
          prompt: prompt,
          images: [image_data],
          photo_id: log.photo_id,
          owner_id: owner_id,
          requester_id: requester_id
        ] ++ Keyword.take(opts, [:target_server])

      OllamaClient.completion(completion_opts)
    else
      {:error, :thumbnail_not_found}
    end
  end

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
        <%!-- Breadcrumb --%>
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/admin/logs"}>{gettext("Logs")}</.link>
            </li>
            <li>{gettext("Ollama Logs")}</li>
          </ul>
        </div>
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Ollama Logs")}</h1>
          <span class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} entry",
              "%{count} entries",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Queue & Model Status --%>
        <div class="flex flex-wrap gap-3 mb-6">
          <div class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2">
            <span class="text-sm text-base-content/60">{gettext("Queue")}</span>
            <span class={[
              "badge badge-sm font-mono",
              if(@queue_count > 0, do: "badge-warning", else: "badge-success")
            ]}>
              {@queue_count}
            </span>
          </div>

          <div class="flex items-center gap-2 bg-base-200 rounded-lg px-4 py-2">
            <span class="text-sm text-base-content/60">{gettext("Model")}</span>
            <span class="badge badge-sm badge-primary font-mono">{@current_model}</span>
            <%= if @adaptive_enabled do %>
              <span class="badge badge-sm badge-ghost">{gettext("adaptive")}</span>
            <% end %>
          </div>

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

        <%!-- View Toggle --%>
        <div class="tabs tabs-boxed mb-4 w-fit">
          <button
            phx-click="switch-view"
            phx-value-view="all"
            class={["tab", if(@view_mode == "all", do: "tab-active")]}
          >
            {gettext("All Logs")}
          </button>
          <button
            phx-click="switch-view"
            phx-value-view="by_photo"
            class={["tab", if(@view_mode == "by_photo", do: "tab-active")]}
          >
            {gettext("By Photo")}
          </button>
        </div>

        <%!-- Filters --%>
        <div class="flex flex-wrap items-end gap-4 mb-4">
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Model")}</span>
            </div>
            <select class="select select-bordered select-sm" phx-change="filter-model" name="model">
              <option value="" selected={is_nil(@filter_model)}>{gettext("All")}</option>
              <%= for model <- @available_models do %>
                <option value={model} selected={@filter_model == model}>{model}</option>
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
              <option value="success" selected={@filter_status == "success"}>
                {gettext("Success")}
              </option>
              <option value="error" selected={@filter_status == "error"}>{gettext("Error")}</option>
              <option value="in_progress" selected={@filter_status == "in_progress"}>
                {gettext("In Progress")}
              </option>
            </select>
          </label>

          <div class="form-control">
            <div class="label">
              <span class="label-text">{gettext("Per page")}</span>
            </div>
            <div class="join">
              <%= for size <- [50, 100, 150, 500] do %>
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

        <%!-- Content --%>
        <%= if @view_mode == "by_photo" && @grouped_data do %>
          <.grouped_view grouped_data={@grouped_data} rerunning={@rerunning} />
        <% else %>
          <.logs_table
            logs={@logs}
            sort_by={@sort_by}
            sort_dir={@sort_dir}
            rerunning={@rerunning}
          />
        <% end %>

        <%!-- Pagination --%>
        <.pagination page={@page} total_pages={@total_pages} />
      </div>
    </Layouts.app>
    """
  end

  defp logs_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm">
        <thead>
          <tr>
            <th>{gettext("Photo")}</th>
            <th class="cursor-pointer hover:bg-base-200" phx-click="sort" phx-value-column="model">
              {gettext("Model")}
              <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:model} />
            </th>
            <th>{gettext("Server")}</th>
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
              phx-value-column="duration_ms"
            >
              {gettext("Duration")}
              <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:duration_ms} />
            </th>
            <th
              class="cursor-pointer hover:bg-base-200"
              phx-click="sort"
              phx-value-column="inserted_at"
            >
              {gettext("Time")}
              <.sort_indicator sort_by={@sort_by} sort_dir={@sort_dir} column={:inserted_at} />
            </th>
            <th class="text-center">{gettext("Avatar")}</th>
            <th class="text-center">{gettext("Moodboard")}</th>
            <th>{gettext("Re-run")}</th>
          </tr>
        </thead>
        <tbody>
          <%= for log <- @logs do %>
            <tr class={
              cond do
                log.status == "error" -> "bg-error/5"
                log.status == "in_progress" -> "bg-warning/5"
                true -> nil
              end
            }>
              <td>
                <.photo_thumbnail photo={log.photo} owner={log.owner} />
              </td>
              <td><span class="badge badge-sm badge-ghost font-mono">{log.model}</span></td>
              <td>
                <span class="text-xs text-base-content/50 font-mono">
                  {format_server_url(log.server_url)}
                </span>
              </td>
              <td>
                <span class={[
                  "badge badge-sm",
                  cond do
                    log.status == "success" -> "badge-success"
                    log.status == "in_progress" -> "badge-warning"
                    true -> "badge-error"
                  end
                ]}>
                  {log.status}
                </span>
                <%= if log.requester do %>
                  <span class="text-xs text-base-content/50 ml-1" title={gettext("Manual re-run")}>
                    ({log.requester.display_name})
                  </span>
                <% end %>
              </td>
              <td>
                <span class="font-mono text-sm">
                  {format_duration(log.duration_ms)}
                </span>
              </td>
              <td>
                <span class="text-xs" title={format_datetime(log.inserted_at)}>
                  {relative_time(log.inserted_at)}
                </span>
              </td>
              <td class="text-center">
                <.verdict_dot verdict={avatar_verdict(log)} />
              </td>
              <td class="text-center">
                <.verdict_dot verdict={moodboard_verdict(log)} />
              </td>
              <td>
                <.rerun_buttons log={log} rerunning={@rerunning} />
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp grouped_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= if @grouped_data == [] do %>
        <div class="text-center py-8 text-base-content/50">
          {gettext("No grouped log entries found.")}
        </div>
      <% end %>
      <%= for group <- @grouped_data do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body p-4">
            <div class="flex items-center gap-4 mb-3">
              <.photo_thumbnail photo={group.photo} owner={group.owner} />
              <div>
                <div class="font-semibold text-sm">
                  <%= if group.photo do %>
                    <a
                      href={~p"/admin/photos/#{group.photo_id}/history"}
                      class="link link-primary"
                    >
                      {String.slice(group.photo_id, 0, 8)}...
                    </a>
                  <% else %>
                    <span class="text-base-content/50">{gettext("Photo deleted")}</span>
                  <% end %>
                </div>
                <%= if group.owner do %>
                  <div class="text-xs text-base-content/60">{group.owner.display_name}</div>
                <% end %>
                <div class="text-xs text-base-content/50">
                  {ngettext("%{count} run", "%{count} runs", group.count, count: group.count)}
                </div>
              </div>
              <div class="ml-auto">
                <.agreement_badge agreement={group.agreement} />
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="table table-xs">
                <thead>
                  <tr>
                    <th>{gettext("Model")}</th>
                    <th>{gettext("Duration")}</th>
                    <th>{gettext("Server")}</th>
                    <th>{gettext("Status")}</th>
                    <th class="text-center">{gettext("Avatar")}</th>
                    <th class="text-center">{gettext("Moodboard")}</th>
                    <th>{gettext("Re-run")}</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for entry <- group.entries do %>
                    <tr>
                      <td>
                        <span class="badge badge-xs badge-ghost font-mono">{entry.model}</span>
                      </td>
                      <td class="font-mono text-xs">
                        {format_duration(entry.duration_ms)}
                      </td>
                      <td class="text-xs text-base-content/50 font-mono">
                        {format_server_url(entry.server_url)}
                      </td>
                      <td>
                        <span class={[
                          "badge badge-xs",
                          cond do
                            entry.status == "success" -> "badge-success"
                            entry.status == "in_progress" -> "badge-warning"
                            true -> "badge-error"
                          end
                        ]}>
                          {entry.status}
                        </span>
                      </td>
                      <td class="text-center">
                        <.verdict_dot verdict={avatar_verdict(entry)} />
                      </td>
                      <td class="text-center">
                        <.verdict_dot verdict={moodboard_verdict(entry)} />
                      </td>
                      <td>
                        <.rerun_buttons log={entry} rerunning={@rerunning} />
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp photo_thumbnail(assigns) do
    assigns = assign_new(assigns, :owner, fn -> nil end)

    ~H"""
    <%= if @photo do %>
      <a href={~p"/admin/photos/#{@photo.id}/history"} class="block">
        <img
          src={Photos.signed_url(@photo, :thumbnail)}
          class="w-12 h-12 object-cover rounded"
          loading="lazy"
          title={owner_tooltip(@owner)}
        />
      </a>
    <% else %>
      <div class="w-12 h-12 bg-base-300 rounded flex items-center justify-center">
        <span class="text-xs text-base-content/30">-</span>
      </div>
    <% end %>
    """
  end

  defp verdict_dot(%{verdict: nil} = assigns) do
    ~H"""
    <span class="text-base-content/20">-</span>
    """
  end

  defp verdict_dot(%{verdict: :approved} = assigns) do
    ~H"""
    <span class="inline-block w-2.5 h-2.5 rounded-full bg-success" title={gettext("Approved")}></span>
    """
  end

  defp verdict_dot(%{verdict: {:rejected, _reason}} = assigns) do
    ~H"""
    <span class="inline-block w-2.5 h-2.5 rounded-full bg-error" title={@verdict |> elem(1)}></span>
    """
  end

  defp rerun_buttons(assigns) do
    assigns =
      assigns
      |> assign(:all_models, @available_models)
      |> assign(:other_servers, other_servers(assigns.log.server_url))

    ~H"""
    <%= if @log.photo_id do %>
      <div class="flex flex-col gap-1">
        <%!-- Model buttons — all sizes in order, current model highlighted --%>
        <div class="flex gap-1">
          <%= if MapSet.member?(@rerunning, @log.id) do %>
            <span class="btn btn-xs btn-disabled loading loading-spinner loading-xs"></span>
          <% else %>
            <%= for model <- @all_models do %>
              <button
                class={[
                  "btn btn-xs",
                  if(model == @log.model, do: "btn-primary", else: "btn-outline btn-primary")
                ]}
                phx-click="rerun_with_model"
                phx-value-log_id={@log.id}
                phx-value-model={model}
                title={gettext("Re-run with %{model}", model: model)}
              >
                {model |> String.split(":") |> List.last()}
              </button>
            <% end %>
          <% end %>
        </div>
        <%!-- Server buttons --%>
        <%= if @other_servers != [] do %>
          <div class="flex gap-1">
            <%= if MapSet.member?(@rerunning, @log.id) do %>
              <span class="btn btn-xs btn-disabled loading loading-spinner loading-xs"></span>
            <% else %>
              <%= for server <- @other_servers do %>
                <button
                  class="btn btn-xs btn-outline btn-secondary"
                  phx-click="rerun_on_server"
                  phx-value-log_id={@log.id}
                  phx-value-server={server}
                  title={gettext("Re-run on %{server}", server: server)}
                >
                  {format_server_url(server)}
                </button>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp agreement_badge(assigns) do
    ~H"""
    <%= case @agreement do %>
      <% :agree -> %>
        <span class="badge badge-success badge-sm">{gettext("Agree")}</span>
      <% :disagree -> %>
        <span class="badge badge-error badge-sm">{gettext("Disagree")}</span>
      <% :single -> %>
        <span class="badge badge-ghost badge-sm">{gettext("Single")}</span>
      <% _ -> %>
        <span class="badge badge-ghost badge-sm">-</span>
    <% end %>
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

    pages =
      if current > 3, do: pages ++ [:gap], else: pages

    middle_start = max(2, current - 1)
    middle_end = min(total - 1, current + 1)

    pages = pages ++ Enum.to_list(middle_start..middle_end)

    pages =
      if current < total - 2, do: pages ++ [:gap], else: pages

    pages = pages ++ [total]
    Enum.uniq(pages)
  end

  defp format_duration(nil), do: ""
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) do
    seconds = ms / 1000
    :erlang.float_to_binary(seconds, decimals: 1) <> "s"
  end

  defp format_server_url(nil), do: ""

  defp format_server_url(url) do
    url
    |> String.replace(~r{^https?://}, "")
    |> String.replace(~r{/api/?$}, "")
  end

  defp available_servers do
    Photos.ollama_instances()
    |> Enum.map(& &1.url)
  end

  defp other_servers(current_server_url) do
    available_servers()
    |> Enum.reject(&(&1 == current_server_url))
  end

  defp owner_tooltip(nil), do: ""

  defp owner_tooltip(owner) do
    if owner.email do
      "#{owner.display_name}\n#{owner.email}"
    else
      owner.display_name
    end
  end
end
