defmodule AniminaWeb.Admin.PhotoBlacklistLive do
  use AniminaWeb, :live_view

  alias Animina.Photos

  import AniminaWeb.Helpers.AdminHelpers, only: [parse_int: 2]

  @default_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Photo Blacklist"),
       confirm_delete: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_int(params["page"], 1)
    per_page = parse_int(params["per_page"], @default_per_page)
    viewer_id = socket.assigns.current_scope.user.id

    result =
      Photos.list_blacklist_entries_paginated(
        page: page,
        per_page: per_page,
        viewer_id: viewer_id
      )

    {:noreply,
     assign(socket,
       entries: result.entries,
       page: result.page,
       per_page: result.per_page,
       total_count: result.total_count,
       total_pages: result.total_pages
     )}
  end

  @impl true
  def handle_event("confirm-delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirm_delete: id)}
  end

  @impl true
  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete: nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Photos.get_blacklist_entry(id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Entry not found."))}

      entry ->
        case Photos.remove_from_blacklist(entry) do
          {:ok, _} ->
            socket =
              socket
              |> reload_entries()
              |> assign(confirm_delete: nil)
              |> put_flash(:info, gettext("Blacklist entry deleted."))

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Could not delete entry."))}
        end
    end
  end

  @impl true
  def handle_event("change-per-page", %{"per_page" => per_page}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/photo-blacklist?#{%{page: 1, per_page: per_page}}"
     )}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/photo-blacklist?#{%{page: page, per_page: socket.assigns.per_page}}"
     )}
  end

  defp reload_entries(socket) do
    viewer_id = socket.assigns.current_scope.user.id

    result =
      Photos.list_blacklist_entries_paginated(
        page: socket.assigns.page,
        per_page: socket.assigns.per_page,
        viewer_id: viewer_id
      )

    assign(socket,
      entries: result.entries,
      total_count: result.total_count,
      total_pages: result.total_pages
    )
  end

  defp format_dhash(nil), do: "-"

  defp format_dhash(dhash) when is_binary(dhash) do
    dhash
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp format_date(nil), do: "-"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/admin"}>{gettext("Admin")}</.link>
            </li>
            <li>{gettext("Photo Blacklist")}</li>
          </ul>
        </div>
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Photo Blacklist")}</h1>
          <p class="text-base-content/70 mt-1">
            {gettext(
              "Manage blacklisted photo hashes. Photos matching these hashes are automatically rejected."
            )}
          </p>
        </div>

        <%= if Enum.empty?(@entries) do %>
          <div class="bg-base-200 rounded-lg p-8 text-center">
            <.icon name="hero-shield-check" class="h-12 w-12 mx-auto text-base-content/30 mb-3" />
            <p class="text-base-content/70">{gettext("No blacklist entries yet.")}</p>
          </div>
        <% else %>
          <div class="bg-base-200 rounded-lg p-2 mb-4">
            <span class="text-sm text-base-content/70 px-2">
              {ngettext("%{count} entry", "%{count} entries", @total_count, count: @total_count)}
            </span>
          </div>

          <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            <%= for entry <- @entries do %>
              <div class="bg-base-200 rounded-lg overflow-hidden shadow-sm">
                <%!-- Thumbnail --%>
                <div class="bg-base-300 flex items-center justify-center">
                  <%= if entry.thumbnail_path && File.exists?(entry.thumbnail_path) do %>
                    <img
                      src={blacklist_thumbnail_url(entry)}
                      alt={gettext("Blacklisted photo")}
                      class="max-w-full h-auto"
                    />
                  <% else %>
                    <div class="text-center text-base-content/30">
                      <.icon name="hero-photo" class="h-12 w-12 mx-auto mb-2" />
                      <span class="text-sm">{gettext("No thumbnail")}</span>
                    </div>
                  <% end %>
                </div>

                <%!-- Info --%>
                <div class="p-4 space-y-2">
                  <div class="flex items-start justify-between gap-2">
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-base-content truncate" title={entry.reason}>
                        {entry.reason}
                      </p>
                      <p class="text-xs text-base-content/50 font-mono">
                        {format_dhash(entry.dhash)}...
                      </p>
                    </div>
                  </div>

                  <div class="text-xs text-base-content/50 space-y-1">
                    <p>
                      <span class="font-medium">{gettext("Added:")}</span>
                      {format_date(entry.inserted_at)}
                    </p>
                    <%= if entry.added_by do %>
                      <p>
                        <span class="font-medium">{gettext("By:")}</span>
                        {entry.added_by.email}
                      </p>
                    <% end %>
                    <%= if entry.source_user do %>
                      <p>
                        <span class="font-medium">{gettext("Source user:")}</span>
                        {entry.source_user.email}
                      </p>
                    <% end %>
                  </div>

                  <%!-- Delete button --%>
                  <div class="pt-2 border-t border-base-300">
                    <%= if @confirm_delete == entry.id do %>
                      <div class="flex items-center gap-2">
                        <span class="text-sm text-warning flex-1">
                          {gettext("Delete this entry?")}
                        </span>
                        <button
                          type="button"
                          class="btn btn-ghost btn-xs"
                          phx-click="cancel-delete"
                        >
                          {gettext("Cancel")}
                        </button>
                        <button
                          type="button"
                          class="btn btn-error btn-xs"
                          phx-click="delete"
                          phx-value-id={entry.id}
                        >
                          {gettext("Delete")}
                        </button>
                      </div>
                    <% else %>
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm btn-block text-error"
                        phx-click="confirm-delete"
                        phx-value-id={entry.id}
                      >
                        <.icon name="hero-trash" class="h-4 w-4" />
                        {gettext("Remove from blacklist")}
                      </button>
                    <% end %>
                  </div>
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
              <div class="btn-group">
                <%= for size <- [50, 100, 250] do %>
                  <button
                    type="button"
                    class={[
                      "btn btn-xs",
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
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp blacklist_thumbnail_url(entry) do
    # Serve via a simple static path - the file is in uploads/blacklist/
    "/uploads/blacklist/" <> Path.basename(entry.thumbnail_path)
  end
end
