defmodule AniminaWeb.Admin.PhotoReviewsLive do
  use AniminaWeb, :live_view

  alias Animina.Photos

  import AniminaWeb.Helpers.AdminHelpers,
    only: [parse_int: 2, humanize_key: 1, format_value: 1, format_datetime: 1]

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Photo Reviews"),
       selected_appeal: nil,
       reviewer_notes: "",
       add_to_blacklist: false,
       # Bulk selection
       selected_ids: MapSet.new(),
       bulk_blacklist: true,
       last_clicked_id: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    viewer_id = socket.assigns.current_scope.user.id

    result =
      Photos.list_pending_appeals_paginated(
        page: page,
        per_page: per_page,
        viewer_id: viewer_id
      )

    {:noreply,
     assign(socket,
       appeals: result.entries,
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages,
       selected_ids: MapSet.new()
     )}
  end

  @impl true
  def handle_event("select-appeal", %{"id" => id}, socket) do
    appeal = Photos.get_appeal!(id)
    photo = Photos.get_photo!(appeal.photo_id)
    history = Photos.get_photo_history(photo.id)

    # Filter to show only AI decisions
    ai_history =
      Enum.filter(history, fn event ->
        event.actor_type == "ai" or
          event.event_type in ["blacklist_matched", "photo_rejected", "age_detected"]
      end)

    # Check if photo is already blacklisted
    is_blacklisted =
      if photo.dhash do
        Photos.get_blacklist_entry_by_dhash(photo.dhash) != nil
      else
        false
      end

    {:noreply,
     assign(socket,
       selected_appeal: appeal,
       selected_photo: photo,
       photo_history: ai_history,
       is_blacklisted: is_blacklisted,
       reviewer_notes: "",
       add_to_blacklist: true,
       remove_from_blacklist: false
     )}
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
  def handle_event("toggle-remove-blacklist", _params, socket) do
    {:noreply, assign(socket, remove_from_blacklist: !socket.assigns.remove_from_blacklist)}
  end

  @impl true
  def handle_event("approve", _params, socket) do
    appeal = socket.assigns.selected_appeal
    reviewer = socket.assigns.current_scope.user

    opts = [
      reviewer_notes: socket.assigns.reviewer_notes,
      remove_from_blacklist: socket.assigns[:remove_from_blacklist] || false
    ]

    case Photos.resolve_appeal(appeal, reviewer, "approved", opts) do
      {:ok, _result} ->
        socket =
          socket
          |> reload_appeals()
          |> assign(selected_appeal: nil)
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
    appeal = socket.assigns.selected_appeal
    reviewer = socket.assigns.current_scope.user

    opts = [
      reviewer_notes: socket.assigns.reviewer_notes,
      add_to_blacklist: socket.assigns.add_to_blacklist,
      blacklist_reason: socket.assigns.reviewer_notes
    ]

    case Photos.resolve_appeal(appeal, reviewer, "rejected", opts) do
      {:ok, _result} ->
        socket =
          socket
          |> reload_appeals()
          |> assign(selected_appeal: nil)
          |> put_flash(:info, gettext("Appeal rejected."))

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
  def handle_event("close-modal", _params, socket) do
    {:noreply, assign(socket, selected_appeal: nil)}
  end

  @impl true
  def handle_event("toggle-select", %{"id" => id}, socket) do
    selected_ids = socket.assigns.selected_ids

    new_selected =
      if MapSet.member?(selected_ids, id) do
        MapSet.delete(selected_ids, id)
      else
        MapSet.put(selected_ids, id)
      end

    {:noreply, assign(socket, selected_ids: new_selected, last_clicked_id: id)}
  end

  @impl true
  def handle_event("select-range", %{"id" => id, "last_id" => last_id}, socket) do
    appeals = socket.assigns.appeals
    appeal_ids = Enum.map(appeals, & &1.id)

    idx1 = Enum.find_index(appeal_ids, &(&1 == last_id)) || 0
    idx2 = Enum.find_index(appeal_ids, &(&1 == id)) || 0

    {start_idx, end_idx} = if idx1 <= idx2, do: {idx1, idx2}, else: {idx2, idx1}

    range_ids =
      appeal_ids
      |> Enum.slice(start_idx..end_idx)
      |> MapSet.new()

    new_selected = MapSet.union(socket.assigns.selected_ids, range_ids)

    {:noreply, assign(socket, selected_ids: new_selected, last_clicked_id: id)}
  end

  @impl true
  def handle_event("select-all", _params, socket) do
    all_ids =
      socket.assigns.appeals
      |> Enum.map(& &1.id)
      |> MapSet.new()

    {:noreply, assign(socket, selected_ids: all_ids)}
  end

  @impl true
  def handle_event("deselect-all", _params, socket) do
    {:noreply, assign(socket, selected_ids: MapSet.new())}
  end

  @impl true
  def handle_event("toggle-bulk-blacklist", _params, socket) do
    {:noreply, assign(socket, bulk_blacklist: !socket.assigns.bulk_blacklist)}
  end

  @impl true
  def handle_event("bulk-reject", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_ids)

    if Enum.empty?(selected_ids) do
      {:noreply, put_flash(socket, :warning, gettext("No appeals selected."))}
    else
      reviewer = socket.assigns.current_scope.user

      opts =
        if socket.assigns.bulk_blacklist do
          [add_to_blacklist: true, blacklist_reason: "Bulk rejected"]
        else
          []
        end

      {:ok, %{resolved: resolved, failed: failed}} =
        Photos.bulk_resolve_appeals(selected_ids, reviewer, "rejected", opts)

      socket = reload_appeals(socket)

      message =
        if failed > 0 do
          gettext("Rejected %{resolved} appeals. %{failed} already resolved.",
            resolved: resolved,
            failed: failed
          )
        else
          ngettext(
            "Rejected %{count} appeal.",
            "Rejected %{count} appeals.",
            resolved,
            count: resolved
          )
        end

      {:noreply, put_flash(socket, :info, message)}
    end
  end

  @impl true
  def handle_event("bulk-approve", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_ids)

    if Enum.empty?(selected_ids) do
      {:noreply, put_flash(socket, :warning, gettext("No appeals selected."))}
    else
      reviewer = socket.assigns.current_scope.user

      {:ok, %{resolved: resolved, failed: failed}} =
        Photos.bulk_resolve_appeals(selected_ids, reviewer, "approved", [])

      socket = reload_appeals(socket)

      message =
        if failed > 0 do
          gettext("Approved %{resolved} appeals. %{failed} already resolved.",
            resolved: resolved,
            failed: failed
          )
        else
          ngettext(
            "Approved %{count} appeal.",
            "Approved %{count} appeals.",
            resolved,
            count: resolved
          )
        end

      {:noreply, put_flash(socket, :info, message)}
    end
  end

  @impl true
  def handle_event("change-per-page", %{"per_page" => per_page}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/photo-reviews?#{%{page: 1, per_page: per_page}}"
     )}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/photo-reviews?#{%{page: page, per_page: socket.assigns.per_page}}"
     )}
  end

  @impl true
  def handle_event("keydown", %{"key" => "r"}, socket) do
    if MapSet.size(socket.assigns.selected_ids) > 0 and is_nil(socket.assigns.selected_appeal) do
      handle_event("bulk-reject", %{}, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("keydown", %{"key" => "a"}, socket) do
    if MapSet.size(socket.assigns.selected_ids) > 0 and is_nil(socket.assigns.selected_appeal) do
      handle_event("bulk-approve", %{}, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    if socket.assigns.selected_appeal do
      {:noreply, assign(socket, selected_appeal: nil)}
    else
      {:noreply, assign(socket, selected_ids: MapSet.new())}
    end
  end

  @impl true
  def handle_event("keydown", %{"key" => key, "ctrlKey" => true}, socket)
      when key in ["a", "A"] do
    handle_event("select-all", %{}, socket)
  end

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) when key in ["n", "ArrowRight"] do
    if socket.assigns.page < socket.assigns.total_pages do
      handle_event("go-to-page", %{"page" => socket.assigns.page + 1}, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) when key in ["p", "ArrowLeft"] do
    if socket.assigns.page > 1 do
      handle_event("go-to-page", %{"page" => socket.assigns.page - 1}, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("keydown", _params, socket), do: {:noreply, socket}

  defp reload_appeals(socket) do
    viewer_id = socket.assigns.current_scope.user.id

    result =
      Photos.list_pending_appeals_paginated(
        page: socket.assigns.page,
        per_page: socket.assigns.per_page,
        viewer_id: viewer_id
      )

    assign(socket,
      appeals: result.entries,
      total_count: result.total_count,
      total_pages: result.total_pages,
      selected_ids: MapSet.new()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        phx-window-keydown="keydown"
        id="photo-reviews-container"
        phx-hook="ShiftSelect"
      >
        <%!-- Header with count --%>
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Photo Reviews")}</h1>
          <span class="badge badge-lg badge-outline">
            {ngettext(
              "%{count} pending appeal",
              "%{count} pending appeals",
              @total_count,
              count: @total_count
            )}
          </span>
        </div>

        <%!-- Sticky Toolbar when items selected --%>
        <%= if MapSet.size(@selected_ids) > 0 do %>
          <div class="sticky top-0 z-40 bg-base-100 border border-base-300 rounded-lg p-3 mb-4 shadow-lg flex flex-wrap items-center gap-4">
            <span class="font-medium">
              {ngettext(
                "%{count} selected",
                "%{count} selected",
                MapSet.size(@selected_ids),
                count: MapSet.size(@selected_ids)
              )}
            </span>

            <button type="button" class="btn btn-success btn-sm" phx-click="bulk-approve">
              <.icon name="hero-check" class="h-4 w-4" />
              {gettext("Approve Selected")}
              <kbd class="kbd kbd-xs ml-1">A</kbd>
            </button>

            <button type="button" class="btn btn-error btn-sm" phx-click="bulk-reject">
              <.icon name="hero-x-mark" class="h-4 w-4" />
              {gettext("Reject Selected")}
              <kbd class="kbd kbd-xs ml-1">R</kbd>
            </button>

            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                class="checkbox checkbox-sm checkbox-error"
                checked={@bulk_blacklist}
                phx-click="toggle-bulk-blacklist"
              />
              <span class="text-sm">{gettext("Add to blacklist")}</span>
            </label>

            <button
              type="button"
              class="btn btn-ghost btn-sm ml-auto"
              phx-click="deselect-all"
            >
              {gettext("Clear selection")}
            </button>
          </div>
        <% end %>

        <%= if @appeals == [] do %>
          <div class="text-center py-12">
            <.icon name="hero-check-circle" class="h-16 w-16 mx-auto text-success mb-4" />
            <p class="text-lg text-base-content/70">{gettext("No pending appeals.")}</p>
          </div>
        <% else %>
          <%!-- Grid of photos --%>
          <div class="grid gap-4 grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
            <%= for appeal <- @appeals do %>
              <div
                class="flex flex-col items-center gap-2"
                data-appeal-id={appeal.id}
              >
                <div
                  class={[
                    "relative group cursor-pointer rounded-lg overflow-hidden",
                    if(MapSet.member?(@selected_ids, appeal.id),
                      do: "ring-4 ring-primary",
                      else: "hover:ring-2 hover:ring-primary/50"
                    )
                  ]}
                  phx-click="select-appeal"
                  phx-value-id={appeal.id}
                >
                  <%= if appeal.photo do %>
                    <img
                      src={Photos.signed_url(appeal.photo)}
                      alt={gettext("Photo under review")}
                      class="max-w-full h-auto"
                    />
                  <% else %>
                    <div class="w-32 h-32 bg-base-300 flex items-center justify-center">
                      <.icon name="hero-photo" class="h-12 w-12 text-base-content/30" />
                    </div>
                  <% end %>

                  <%!-- Appeal reason tooltip on hover --%>
                  <%= if appeal.appeal_reason do %>
                    <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent p-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <p class="text-xs text-white line-clamp-2">"{appeal.appeal_reason}"</p>
                    </div>
                  <% end %>
                </div>

                <%!-- Selection checkbox below image --%>
                <input
                  type="checkbox"
                  class="checkbox checkbox-primary"
                  checked={MapSet.member?(@selected_ids, appeal.id)}
                  phx-click="toggle-select"
                  phx-value-id={appeal.id}
                  data-appeal-checkbox={appeal.id}
                  data-last-clicked-id={@last_clicked_id}
                />
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

            <span class="text-sm text-base-content/50">
              {ngettext("%{count} total", "%{count} total", @total_count, count: @total_count)}
            </span>
          </div>

          <%!-- Keyboard shortcuts hint --%>
          <div class="text-xs text-base-content/40 mt-4 flex flex-wrap gap-4">
            <span><kbd class="kbd kbd-xs">Ctrl+A</kbd> {gettext("Select all")}</span>
            <span><kbd class="kbd kbd-xs">A</kbd> {gettext("Approve selected")}</span>
            <span><kbd class="kbd kbd-xs">R</kbd> {gettext("Reject selected")}</span>
            <span><kbd class="kbd kbd-xs">Esc</kbd> {gettext("Close / Deselect")}</span>
            <span>
              <kbd class="kbd kbd-xs">←</kbd><kbd class="kbd kbd-xs">→</kbd> {gettext(
                "Navigate pages"
              )}
            </span>
            <span>
              <kbd class="kbd kbd-xs">Shift</kbd>+{gettext("Click")} {gettext("Range select")}
            </span>
          </div>
        <% end %>

        <%!-- Review Modal --%>
        <%= if @selected_appeal do %>
          <div class="modal modal-open" phx-window-keydown="close-modal" phx-key="escape">
            <div class="modal-box max-w-2xl">
              <button
                type="button"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
                phx-click="close-modal"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>

              <h3 class="font-bold text-lg mb-4">{gettext("Review Appeal")}</h3>

              <div class="grid md:grid-cols-2 gap-6">
                <%!-- Photo Preview --%>
                <div>
                  <%= if @selected_appeal.photo do %>
                    <img
                      src={Photos.signed_url(@selected_appeal.photo)}
                      alt={gettext("Photo under review")}
                      class="w-full rounded-lg"
                    />
                  <% end %>
                </div>

                <%!-- Details --%>
                <div class="space-y-4">
                  <div>
                    <p class="text-sm font-medium text-base-content/70">{gettext("User")}</p>
                    <p class="font-medium">
                      {@selected_appeal.user && @selected_appeal.user.display_name}
                    </p>
                    <p class="text-sm text-base-content/50">
                      {@selected_appeal.user && @selected_appeal.user.email}
                    </p>
                  </div>

                  <%!-- AI Decisions History --%>
                  <%= if @photo_history != [] do %>
                    <div>
                      <p class="text-sm font-medium text-base-content/70 mb-2">
                        {gettext("AI Analysis")}
                      </p>
                      <div class="space-y-2">
                        <%= for event <- @photo_history do %>
                          <div class="text-xs bg-base-300 rounded p-2">
                            <div class="flex items-center gap-2 mb-1">
                              <span class={[
                                "badge badge-xs",
                                if(event.actor_type == "ai", do: "badge-info", else: "badge-ghost")
                              ]}>
                                {event.actor_type}
                              </span>
                              <span class="font-medium">{event_label(event.event_type)}</span>
                              <%!-- Duration badge --%>
                              <%= if event.duration_ms do %>
                                <span class="badge badge-xs badge-ghost">
                                  {format_duration(event.duration_ms)}
                                </span>
                              <% end %>
                            </div>
                            <%= if event.details && map_size(event.details) > 0 do %>
                              <div class="text-base-content/60">
                                <%= for {key, value} <- event.details do %>
                                  <span class="mr-2">{humanize_key(key)}: {format_value(value)}</span>
                                <% end %>
                              </div>
                            <% end %>
                            <%!-- Ollama server URL --%>
                            <%= if event.ollama_server_url do %>
                              <div class="text-base-content/40 mt-1">
                                {gettext("Server")}: {format_server_url(event.ollama_server_url)}
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <%= if @selected_appeal.appeal_reason do %>
                    <div>
                      <p class="text-sm font-medium text-base-content/70">
                        {gettext("Appeal Reason")}
                      </p>
                      <p class="text-sm">{@selected_appeal.appeal_reason}</p>
                    </div>
                  <% end %>

                  <div>
                    <p class="text-sm font-medium text-base-content/70">{gettext("Submitted")}</p>
                    <p class="text-sm">{format_datetime(@selected_appeal.inserted_at)}</p>
                  </div>

                  <%!-- View History Link --%>
                  <%= if @selected_appeal.photo do %>
                    <div>
                      <.link
                        navigate={~p"/admin/photos/#{@selected_appeal.photo.id}/history"}
                        class="link link-primary text-sm"
                      >
                        <.icon name="hero-clock" class="h-4 w-4 inline mr-1" />
                        {gettext("View full history")}
                      </.link>
                    </div>
                  <% end %>
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

              <%!-- Blacklist Options --%>
              <%= if @selected_photo && @selected_photo.dhash do %>
                <div class="form-control mt-4">
                  <%= if @is_blacklisted do %>
                    <label class="label cursor-pointer justify-start gap-3">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-warning"
                        checked={@remove_from_blacklist}
                        phx-click="toggle-remove-blacklist"
                      />
                      <span class="label-text">
                        {gettext("Remove from blacklist")}
                        <span class="text-warning text-xs block">
                          {gettext("This photo is currently blacklisted")}
                        </span>
                      </span>
                    </label>
                  <% else %>
                    <label class="label cursor-pointer justify-start gap-3">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-error"
                        checked={@add_to_blacklist}
                        phx-click="toggle-blacklist"
                      />
                      <span class="label-text">
                        {gettext("Add rejected photo to blacklist automatically")}
                        <span class="text-base-content/50 text-xs block">
                          {gettext("Similar images will be auto-rejected")}
                        </span>
                      </span>
                    </label>
                  <% end %>
                </div>
              <% end %>

              <%!-- Actions --%>
              <div class="modal-action">
                <button type="button" class="btn btn-ghost" phx-click="close-modal">
                  {gettext("Cancel")}
                </button>
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

  defp event_label("nsfw_checked"), do: gettext("NSFW check")
  defp event_label("face_checked"), do: gettext("Face detection")
  defp event_label("age_detected"), do: gettext("Age detection")
  defp event_label("blacklist_checked"), do: gettext("Blacklist check")
  defp event_label("blacklist_matched"), do: gettext("Blacklist match")
  defp event_label("photo_rejected"), do: gettext("Rejected")
  defp event_label("nsfw_escalated_ollama"), do: gettext("NSFW escalated to Ollama")
  defp event_label("face_escalated_ollama"), do: gettext("Face escalated to Ollama")
  defp event_label(other), do: other

  # Format duration in milliseconds to a human-readable string
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}m"

  # Format server URL to show just the host for readability
  defp format_server_url(url) when is_binary(url) do
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

  defp format_server_url(_), do: "-"
end
