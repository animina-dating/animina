defmodule AniminaWeb.Admin.OllamaQueueLive do
  use AniminaWeb, :live_view

  alias Animina.Photos
  alias Animina.Photos.OllamaHealthTracker
  alias Animina.Photos.OllamaRetryScheduler

  import AniminaWeb.Helpers.AdminHelpers,
    only: [parse_int: 2, format_datetime: 1]

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to photo state changes
      Phoenix.PubSub.subscribe(Animina.PubSub, "photos:*")
    end

    {:ok,
     assign(socket,
       page_title: gettext("Ollama Queue"),
       selected_photo: nil,
       reviewer_notes: "",
       add_to_blacklist: false
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    state_filter = params["state"]

    result =
      Photos.list_ollama_queue_paginated(
        page: page,
        per_page: per_page,
        state_filter: state_filter
      )

    # Get scheduler stats
    scheduler_stats = get_scheduler_stats()

    # Get Ollama health status
    ollama_health = get_ollama_health()

    {:noreply,
     assign(socket,
       photos: result.entries,
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages,
       state_filter: state_filter,
       scheduler_stats: scheduler_stats,
       ollama_health: ollama_health
     )}
  end

  @impl true
  def handle_event("select-photo", %{"id" => id}, socket) do
    photo = Photos.get_photo!(id)
    history = Photos.get_photo_history(photo.id)

    {:noreply,
     assign(socket,
       selected_photo: photo,
       photo_history: history,
       reviewer_notes: "",
       add_to_blacklist: false
     )}
  end

  @impl true
  def handle_event("close-modal", _params, socket) do
    {:noreply, assign(socket, selected_photo: nil)}
  end

  @impl true
  def handle_event("update-notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, reviewer_notes: notes)}
  end

  @impl true
  def handle_event("toggle-blacklist", _params, socket) do
    {:noreply, assign(socket, add_to_blacklist: !socket.assigns.add_to_blacklist)}
  end

  @impl true
  def handle_event("approve", _params, socket) do
    photo = socket.assigns.selected_photo
    reviewer = socket.assigns.current_scope.user

    case Photos.approve_from_ollama_queue(photo, reviewer) do
      {:ok, _photo} ->
        socket =
          socket
          |> reload_photos()
          |> assign(selected_photo: nil)
          |> put_flash(:info, gettext("Photo approved."))

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not approve: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event("reject", _params, socket) do
    photo = socket.assigns.selected_photo
    reviewer = socket.assigns.current_scope.user

    opts = [
      add_to_blacklist: socket.assigns.add_to_blacklist,
      blacklist_reason: socket.assigns.reviewer_notes
    ]

    case Photos.reject_from_ollama_queue(photo, reviewer, opts) do
      {:ok, _photo} ->
        socket =
          socket
          |> reload_photos()
          |> assign(selected_photo: nil)
          |> put_flash(:info, gettext("Photo rejected."))

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not reject: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event("retry", _params, socket) do
    photo = socket.assigns.selected_photo
    reviewer = socket.assigns.current_scope.user

    case Photos.retry_from_manual_review(photo, reviewer) do
      {:ok, _photo} ->
        socket =
          socket
          |> reload_photos()
          |> assign(selected_photo: nil)
          |> put_flash(:info, gettext("Photo queued for retry."))

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not queue for retry: %{reason}", reason: inspect(reason))
         )}
    end
  end

  @impl true
  def handle_event("change-per-page", %{"per_page" => per_page}, socket) do
    {:noreply,
     push_patch(socket,
       to: build_path(1, per_page, socket.assigns.state_filter)
     )}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    {:noreply,
     push_patch(socket,
       to: build_path(page, socket.assigns.per_page, socket.assigns.state_filter)
     )}
  end

  @impl true
  def handle_event("filter-state", %{"state" => state}, socket) do
    state_filter = if state == "", do: nil, else: state

    {:noreply,
     push_patch(socket,
       to: build_path(1, socket.assigns.per_page, state_filter)
     )}
  end

  @impl true
  def handle_info({:photo_state_changed, _photo}, socket) do
    {:noreply, reload_photos(socket)}
  end

  @impl true
  def handle_info({:photo_approved, _photo}, socket) do
    {:noreply, reload_photos(socket)}
  end

  defp reload_photos(socket) do
    result =
      Photos.list_ollama_queue_paginated(
        page: socket.assigns.page,
        per_page: socket.assigns.per_page,
        state_filter: socket.assigns.state_filter
      )

    scheduler_stats = get_scheduler_stats()

    assign(socket,
      photos: result.entries,
      total_count: result.total_count,
      total_pages: result.total_pages,
      scheduler_stats: scheduler_stats
    )
  end

  defp get_scheduler_stats do
    if Process.whereis(OllamaRetryScheduler) do
      OllamaRetryScheduler.get_stats()
    else
      %{queue_count: 0, total_processed: 0, total_succeeded: 0, total_failed: 0}
    end
  end

  defp get_ollama_health do
    if Process.whereis(OllamaHealthTracker) do
      OllamaHealthTracker.get_all_statuses()
    else
      []
    end
  end

  defp build_path(page, per_page, state_filter) do
    params = %{page: page, per_page: per_page}
    params = if state_filter, do: Map.put(params, :state, state_filter), else: params
    ~p"/admin/ollama-queue?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl px-4 py-8">
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Ollama Queue")}</h1>
          <span class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} photo pending",
              "%{count} photos pending",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Stats Cards --%>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div class="stat bg-base-200 rounded-lg">
            <div class="stat-title">{gettext("Queue Size")}</div>
            <div class="stat-value text-primary">{@total_count}</div>
          </div>

          <div class="stat bg-base-200 rounded-lg">
            <div class="stat-title">{gettext("Processed")}</div>
            <div class="stat-value">{@scheduler_stats.total_processed}</div>
          </div>

          <div class="stat bg-base-200 rounded-lg">
            <div class="stat-title">{gettext("Succeeded")}</div>
            <div class="stat-value text-success">{@scheduler_stats.total_succeeded}</div>
          </div>

          <div class="stat bg-base-200 rounded-lg">
            <div class="stat-title">{gettext("Failed")}</div>
            <div class="stat-value text-error">{@scheduler_stats.total_failed}</div>
          </div>
        </div>

        <%!-- Ollama Health Status --%>
        <%= if @ollama_health != [] do %>
          <div class="mb-6">
            <h2 class="text-lg font-semibold mb-2">{gettext("Ollama Health")}</h2>
            <div class="flex flex-wrap gap-2">
              <%= for {url, status} <- @ollama_health do %>
                <div class={[
                  "badge gap-2",
                  case status.state do
                    :closed -> "badge-success"
                    :half_open -> "badge-warning"
                    :open -> "badge-error"
                  end
                ]}>
                  <span class="truncate max-w-32">{format_ollama_url(url)}</span>
                  <span class="font-mono text-xs">{status.state}</span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Filter --%>
        <div class="flex flex-wrap items-center gap-4 mb-4">
          <label class="form-control w-full max-w-xs">
            <div class="label">
              <span class="label-text">{gettext("Filter by state")}</span>
            </div>
            <select
              class="select select-bordered"
              phx-change="filter-state"
              name="state"
            >
              <option value="" selected={is_nil(@state_filter)}>{gettext("All")}</option>
              <option value="pending_ollama" selected={@state_filter == "pending_ollama"}>
                {gettext("Pending Ollama")}
              </option>
              <option value="needs_manual_review" selected={@state_filter == "needs_manual_review"}>
                {gettext("Needs Manual Review")}
              </option>
            </select>
          </label>
        </div>

        <%= if @photos == [] do %>
          <div class="text-center py-12">
            <.icon name="hero-check-circle" class="h-16 w-16 mx-auto text-success mb-4" />
            <p class="text-lg text-base-content/70">{gettext("No photos in queue.")}</p>
          </div>
        <% else %>
          <%!-- Photo Grid --%>
          <div class="grid gap-4 grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
            <%= for photo <- @photos do %>
              <div
                class="flex flex-col items-center gap-2 cursor-pointer"
                phx-click="select-photo"
                phx-value-id={photo.id}
              >
                <div class="relative group rounded-lg overflow-hidden hover:ring-2 hover:ring-primary/50">
                  <img
                    src={Photos.signed_url(photo, :thumbnail)}
                    alt={gettext("Photo in queue")}
                    class="max-w-full h-auto"
                  />

                  <%!-- State badge --%>
                  <div class="absolute top-1 left-1">
                    <span class={[
                      "badge badge-sm",
                      case photo.state do
                        "pending_ollama" -> "badge-warning"
                        "needs_manual_review" -> "badge-error"
                        _ -> "badge-ghost"
                      end
                    ]}>
                      {state_label(photo.state)}
                    </span>
                  </div>

                  <%!-- Retry count badge --%>
                  <%= if photo.ollama_retry_count && photo.ollama_retry_count > 0 do %>
                    <div class="absolute top-1 right-1">
                      <span class="badge badge-sm badge-ghost">
                        #{photo.ollama_retry_count}
                      </span>
                    </div>
                  <% end %>

                  <%!-- Next retry time on hover --%>
                  <%= if photo.ollama_retry_at do %>
                    <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent p-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <p class="text-xs text-white">
                        {gettext("Retry")}: {format_relative_time(photo.ollama_retry_at)}
                      </p>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Pagination --%>
          <div class="flex flex-wrap items-center justify-between gap-4 mt-6 pt-4 border-t border-base-300">
            <div class="flex items-center gap-2">
              <button
                type="button"
                class="btn btn-sm btn-outline"
                disabled={@page <= 1}
                phx-click="go-to-page"
                phx-value-page={@page - 1}
              >
                <.icon name="hero-chevron-left" class="h-4 w-4" />
              </button>

              <span class="text-sm">
                {gettext("Page %{page} of %{total}", page: @page, total: @total_pages)}
              </span>

              <button
                type="button"
                class="btn btn-sm btn-outline"
                disabled={@page >= @total_pages}
                phx-click="go-to-page"
                phx-value-page={@page + 1}
              >
                <.icon name="hero-chevron-right" class="h-4 w-4" />
              </button>
            </div>

            <div class="flex items-center gap-2">
              <span class="text-sm text-base-content/70">{gettext("Per page:")}</span>
              <div class="join">
                <%= for size <- [50, 100, 250] do %>
                  <button
                    type="button"
                    class={[
                      "btn btn-xs join-item",
                      if(@per_page == size, do: "btn-primary", else: "btn-outline")
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
        <% end %>

        <%!-- Review Modal --%>
        <%= if @selected_photo do %>
          <div class="modal modal-open" phx-window-keydown="close-modal" phx-key="escape">
            <div class="modal-box max-w-3xl">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-modal"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <h3 class="font-bold text-lg mb-4">{gettext("Review Photo")}</h3>

              <div class="grid md:grid-cols-2 gap-6">
                <%!-- Photo Preview --%>
                <div>
                  <img
                    src={Photos.signed_url(@selected_photo)}
                    alt={gettext("Photo under review")}
                    class="w-full rounded-lg"
                  />
                </div>

                <%!-- Details --%>
                <div class="space-y-4">
                  <div>
                    <p class="text-sm font-medium text-base-content/70">{gettext("State")}</p>
                    <span class={[
                      "badge",
                      case @selected_photo.state do
                        "pending_ollama" -> "badge-warning"
                        "needs_manual_review" -> "badge-error"
                        _ -> "badge-ghost"
                      end
                    ]}>
                      {state_label(@selected_photo.state)}
                    </span>
                  </div>

                  <div>
                    <p class="text-sm font-medium text-base-content/70">{gettext("Retry Count")}</p>
                    <p class="font-medium">{@selected_photo.ollama_retry_count || 0} / 20</p>
                  </div>

                  <%= if @selected_photo.ollama_retry_at do %>
                    <div>
                      <p class="text-sm font-medium text-base-content/70">{gettext("Next Retry")}</p>
                      <p class="font-medium">{format_datetime(@selected_photo.ollama_retry_at)}</p>
                    </div>
                  <% end %>

                  <div>
                    <p class="text-sm font-medium text-base-content/70">{gettext("Uploaded")}</p>
                    <p class="text-sm">{format_datetime(@selected_photo.inserted_at)}</p>
                  </div>

                  <%!-- View History Link --%>
                  <div>
                    <.link
                      navigate={~p"/admin/photos/#{@selected_photo.id}/history"}
                      class="link link-primary text-sm"
                    >
                      <.icon name="hero-clock" class="h-4 w-4 inline mr-1" />
                      {gettext("View full history")}
                    </.link>
                  </div>
                </div>
              </div>

              <%!-- Reviewer Notes --%>
              <div class="form-control mt-6">
                <label class="label">
                  <span class="label-text">{gettext("Reviewer Notes (optional)")}</span>
                </label>
                <textarea
                  class="textarea textarea-bordered"
                  placeholder={gettext("Add notes about your decision...")}
                  phx-change="update-notes"
                  phx-debounce="300"
                  name="notes"
                >{@reviewer_notes}</textarea>
              </div>

              <%!-- Blacklist Option (only for rejection) --%>
              <%= if @selected_photo.dhash do %>
                <div class="form-control mt-4">
                  <label class="label cursor-pointer justify-start gap-3">
                    <input
                      type="checkbox"
                      class="checkbox checkbox-error"
                      checked={@add_to_blacklist}
                      phx-click="toggle-blacklist"
                    />
                    <span class="label-text">
                      {gettext("Add to blacklist if rejected")}
                      <span class="text-base-content/50 text-xs block">
                        {gettext("Similar images will be auto-rejected")}
                      </span>
                    </span>
                  </label>
                </div>
              <% end %>

              <%!-- Actions --%>
              <div class="modal-action">
                <button type="button" class="btn btn-ghost" phx-click="close-modal">
                  {gettext("Cancel")}
                </button>

                <%= if @selected_photo.state == "needs_manual_review" do %>
                  <button type="button" class="btn btn-warning" phx-click="retry">
                    <.icon name="hero-arrow-path" class="h-5 w-5 mr-1" />
                    {gettext("Retry")}
                  </button>
                <% end %>

                <button type="button" class="btn btn-error" phx-click="reject">
                  <.icon name="hero-x-mark" class="h-5 w-5 mr-1" />
                  {gettext("Reject")}
                </button>

                <button type="button" class="btn btn-success" phx-click="approve">
                  <.icon name="hero-check" class="h-5 w-5 mr-1" />
                  {gettext("Approve")}
                </button>
              </div>
            </div>
            <div class="modal-backdrop" phx-click="close-modal"></div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp state_label("pending_ollama"), do: gettext("Pending")
  defp state_label("needs_manual_review"), do: gettext("Manual")
  defp state_label(state), do: state

  defp format_ollama_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host, port: port} when not is_nil(host) ->
        if port && port not in [80, 443] do
          "#{host}:#{port}"
        else
          host
        end

      _ ->
        url
    end
  end

  defp format_ollama_url(_), do: "-"

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(datetime, now)

    cond do
      diff_seconds < 0 -> gettext("overdue")
      diff_seconds < 60 -> gettext("< 1 min")
      diff_seconds < 3600 -> gettext("%{n} min", n: div(diff_seconds, 60))
      diff_seconds < 86_400 -> gettext("%{n} hr", n: div(diff_seconds, 3600))
      true -> gettext("%{n} days", n: div(diff_seconds, 86_400))
    end
  end
end
