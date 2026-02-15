defmodule AniminaWeb.Admin.PhotoDetailLive do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.AI
  alias Animina.Photos

  import AniminaWeb.Helpers.AdminHelpers,
    only: [humanize_key: 1, format_value: 1, format_datetime_full: 1]

  @impl true
  def mount(%{"id" => photo_id}, _session, socket) do
    photo = Photos.get_photo!(photo_id)
    owner = Accounts.get_user(photo.owner_id)
    history = Photos.get_photo_history(photo_id)

    {:ok,
     assign(socket,
       page_title: gettext("Photo Details"),
       photo: photo,
       owner: owner,
       history: history
     )}
  end

  @impl true
  def handle_event("regenerate-description", _params, socket) do
    photo = socket.assigns.photo
    admin = socket.assigns.current_scope.user

    case AI.enqueue("photo_description", %{"photo_id" => photo.id},
           priority: 4,
           subject_type: "Photo",
           subject_id: photo.id,
           requester_id: admin.id
         ) do
      {:ok, _job} ->
        Animina.ActivityLog.log(
          "admin",
          "photo_description_regenerated",
          "Admin #{admin.display_name} requested description regeneration for photo #{String.slice(photo.id, 0, 8)}",
          actor_id: admin.id,
          metadata: %{"photo_id" => photo.id}
        )

        {:noreply,
         put_flash(
           socket,
           :info,
           gettext("Description regeneration job enqueued.")
         )}

      {:error, _reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Failed to enqueue description job.")
         )}
    end
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
            <li>
              <.link navigate={~p"/admin/photos"}>{gettext("Photo Explorer")}</.link>
            </li>
            <li>{gettext("Photo Details")}</li>
          </ul>
        </div>

        <%!-- Header with photo preview --%>
        <div class="flex items-start gap-6 mb-8">
          <div class="shrink-0">
            <img
              src={Photos.signed_url(@photo)}
              alt={gettext("Photo")}
              class="w-64 h-64 rounded-lg object-cover"
            />
          </div>
          <div>
            <h1 class="text-2xl font-bold text-base-content mb-2">{gettext("Photo Details")}</h1>
            <div class="flex flex-wrap gap-2 mb-3">
              <span class={["badge", state_badge_class(@photo.state)]}>
                {@photo.state}
              </span>
              <span :if={@photo.nsfw} class="badge badge-warning">{gettext("NSFW")}</span>
              <span :if={@photo.has_face == false} class="badge badge-error">
                {gettext("No Face")}
              </span>
            </div>
            <div class="text-sm text-base-content/60 space-y-1">
              <p>
                <span class="font-medium">{gettext("Owner")}:</span>
                <%= if @owner do %>
                  <.link
                    navigate={~p"/users/#{@owner.id}"}
                    class="link link-primary"
                  >
                    {@owner.display_name}
                  </.link>
                  <span class="text-base-content/40 ml-1">({@owner.email})</span>
                <% else %>
                  <span class="text-base-content/40">{gettext("Deleted user")}</span>
                <% end %>
              </p>
              <p>
                <span class="font-medium">{gettext("ID")}:</span>
                <span class="font-mono text-xs">{@photo.id}</span>
              </p>
            </div>
          </div>
        </div>

        <div class="grid gap-6 lg:grid-cols-2">
          <%!-- Photo Details Card --%>
          <div class="card bg-base-200 border border-base-300">
            <div class="card-body">
              <h2 class="card-title text-base">{gettext("Photo Info")}</h2>
              <div class="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                <.detail_row label={gettext("Type")} value={@photo.type || "-"} />
                <.detail_row
                  label={gettext("Original Filename")}
                  value={@photo.original_filename || "-"}
                />
                <.detail_row label={gettext("Content Type")} value={@photo.content_type || "-"} />
                <.detail_row
                  label={gettext("Dimensions")}
                  value={if @photo.width, do: "#{@photo.width} x #{@photo.height}", else: "-"}
                />
                <.detail_row label={gettext("Position")} value={to_string(@photo.position)} />
                <.detail_row label={gettext("NSFW")} value={to_string(@photo.nsfw)} />
                <.detail_row
                  label={gettext("Has Face")}
                  value={if(is_nil(@photo.has_face), do: "-", else: to_string(@photo.has_face))}
                />
                <.detail_row label={gettext("Error")} value={@photo.error_message || "-"} />
                <.detail_row
                  label={gettext("Created")}
                  value={format_datetime_full(@photo.inserted_at)}
                />
                <.detail_row
                  label={gettext("Updated")}
                  value={format_datetime_full(@photo.updated_at)}
                />
              </div>
            </div>
          </div>

          <%!-- AI Description Card --%>
          <div class="card bg-base-200 border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-base">{gettext("AI Description")}</h2>
                <button
                  class="btn btn-sm btn-outline btn-accent"
                  phx-click="regenerate-description"
                >
                  <.icon name="hero-sparkles" class="h-4 w-4" />
                  {gettext("Regenerate Description")}
                </button>
              </div>
              <%= if @photo.description do %>
                <p class="text-sm mt-2">{@photo.description}</p>
                <div class="flex flex-wrap gap-4 mt-3 text-xs text-base-content/50">
                  <span :if={@photo.description_model}>
                    <span class="font-medium">{gettext("Model")}:</span>
                    {@photo.description_model}
                  </span>
                  <span :if={@photo.description_generated_at}>
                    <span class="font-medium">{gettext("Generated")}:</span>
                    {format_datetime_full(@photo.description_generated_at)}
                  </span>
                </div>
              <% else %>
                <p class="text-sm text-base-content/50 italic mt-2">
                  {gettext("No description generated yet.")}
                </p>
              <% end %>
            </div>
          </div>

          <%!-- Technical Details Card --%>
          <div class="card bg-base-200 border border-base-300">
            <div class="card-body">
              <h2 class="card-title text-base">{gettext("Technical Details")}</h2>
              <div class="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                <.detail_row
                  label={gettext("dHash")}
                  value={if @photo.dhash, do: Base.encode16(@photo.dhash, case: :lower), else: "-"}
                />
                <.detail_row
                  label={gettext("Ollama Retry Count")}
                  value={to_string(@photo.ollama_retry_count)}
                />
                <.detail_row
                  label={gettext("Ollama Retry At")}
                  value={
                    if @photo.ollama_retry_at,
                      do: format_datetime_full(@photo.ollama_retry_at),
                      else: "-"
                  }
                />
                <.detail_row
                  label={gettext("Ollama Check Type")}
                  value={@photo.ollama_check_type || "-"}
                />
              </div>
            </div>
          </div>
        </div>

        <%!-- Audit History --%>
        <div class="mt-8">
          <h2 class="text-xl font-bold text-base-content mb-4">{gettext("Audit History")}</h2>

          <%= if @history == [] do %>
            <div class="text-center py-8">
              <.icon
                name="hero-document-text"
                class="h-12 w-12 mx-auto text-base-content/20 mb-3"
              />
              <p class="text-base-content/50">
                {gettext("No history recorded for this photo.")}
              </p>
            </div>
          <% else %>
            <div class="relative">
              <div class="absolute left-4 top-0 bottom-0 w-0.5 bg-base-300"></div>
              <div class="space-y-4">
                <%= for event <- @history do %>
                  <div class="relative flex gap-4">
                    <div class={[
                      "relative z-10 w-8 h-8 rounded-full flex items-center justify-center shrink-0",
                      actor_color(event.actor_type)
                    ]}>
                      <.icon name={actor_icon(event.actor_type)} class="h-4 w-4" />
                    </div>

                    <div class="flex-1 card bg-base-200 border border-base-300">
                      <div class="card-body p-4">
                        <div class="flex items-center justify-between gap-4">
                          <div>
                            <p class="font-medium">{event_label(event.event_type)}</p>
                            <p class="text-xs text-base-content/50">
                              {format_datetime_full(event.inserted_at)}
                              <span class={[
                                "ml-2 badge badge-xs",
                                actor_badge_class(event.actor_type)
                              ]}>
                                {actor_label(event.actor_type)}
                              </span>
                              <span :if={event.actor} class="ml-1">
                                - {event.actor.display_name}
                              </span>
                            </p>
                          </div>
                        </div>

                        <%= if event.duration_ms || event.ollama_server_url do %>
                          <div class="mt-2 flex flex-wrap gap-2">
                            <span :if={event.duration_ms} class="badge badge-sm badge-ghost">
                              <.icon name="hero-clock" class="h-3 w-3 mr-1" />
                              {format_duration(event.duration_ms)}
                            </span>
                            <span :if={event.ollama_server_url} class="badge badge-sm badge-ghost">
                              <.icon name="hero-server" class="h-3 w-3 mr-1" />
                              {format_server_url(event.ollama_server_url)}
                            </span>
                          </div>
                        <% end %>

                        <%= if event.details && map_size(event.details) > 0 do %>
                          <div class="mt-2 text-sm text-base-content/70">
                            <%= for {key, value} <- event.details do %>
                              <div class="flex gap-2">
                                <span class="font-medium text-base-content/50">
                                  {humanize_key(key)}:
                                </span>
                                <span>{format_value(value)}</span>
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp detail_row(assigns) do
    ~H"""
    <div class="text-base-content/50 font-medium">{@label}</div>
    <div class="break-all">{@value}</div>
    """
  end

  # Timeline helpers (shared with photo_history_live.ex)

  defp event_label("photo_uploaded"), do: gettext("Photo uploaded")
  defp event_label("processing_started"), do: gettext("Processing started")
  defp event_label("processing_completed"), do: gettext("Processing completed")
  defp event_label("blacklist_checked"), do: gettext("Blacklist checked")
  defp event_label("blacklist_matched"), do: gettext("Blacklist match found")
  defp event_label("nsfw_checked"), do: gettext("NSFW check completed")
  defp event_label("nsfw_escalated_ollama"), do: gettext("Escalated to Ollama (NSFW)")
  defp event_label("face_checked"), do: gettext("Face detection completed")
  defp event_label("face_escalated_ollama"), do: gettext("Escalated to Ollama (Face)")
  defp event_label("photo_approved"), do: gettext("Photo approved")
  defp event_label("photo_rejected"), do: gettext("Photo rejected")
  defp event_label("appeal_created"), do: gettext("Appeal submitted")
  defp event_label("appeal_approved"), do: gettext("Appeal approved")
  defp event_label("appeal_rejected"), do: gettext("Appeal rejected")
  defp event_label("blacklist_added"), do: gettext("Added to blacklist")
  defp event_label("blacklist_removed"), do: gettext("Removed from blacklist")
  defp event_label(other), do: other

  defp actor_label("system"), do: gettext("System")
  defp actor_label("ai"), do: gettext("AI")
  defp actor_label("user"), do: gettext("User")
  defp actor_label("moderator"), do: gettext("Moderator")
  defp actor_label("admin"), do: gettext("Admin")
  defp actor_label(other), do: other

  defp actor_icon("system"), do: "hero-cog-6-tooth"
  defp actor_icon("ai"), do: "hero-cpu-chip"
  defp actor_icon("user"), do: "hero-user"
  defp actor_icon("moderator"), do: "hero-shield-check"
  defp actor_icon("admin"), do: "hero-key"
  defp actor_icon(_), do: "hero-question-mark-circle"

  defp actor_color("system"), do: "bg-base-300 text-base-content"
  defp actor_color("ai"), do: "bg-info text-info-content"
  defp actor_color("user"), do: "bg-primary text-primary-content"
  defp actor_color("moderator"), do: "bg-warning text-warning-content"
  defp actor_color("admin"), do: "bg-error text-error-content"
  defp actor_color(_), do: "bg-base-300 text-base-content"

  defp actor_badge_class("system"), do: "badge-ghost"
  defp actor_badge_class("ai"), do: "badge-info"
  defp actor_badge_class("user"), do: "badge-primary"
  defp actor_badge_class("moderator"), do: "badge-warning"
  defp actor_badge_class("admin"), do: "badge-error"
  defp actor_badge_class(_), do: "badge-ghost"

  defp state_badge_class("approved"), do: "badge-success"
  defp state_badge_class("appeal_pending"), do: "badge-info"
  defp state_badge_class("appeal_rejected"), do: "badge-error"
  defp state_badge_class("no_face_error"), do: "badge-error"
  defp state_badge_class("error"), do: "badge-error"
  defp state_badge_class(_), do: "badge-warning"

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}m"

  defp format_server_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host, port: port} when not is_nil(host) ->
        if port && port not in [80, 443], do: "#{host}:#{port}", else: host

      _ ->
        url
    end
  end

  defp format_server_url(_), do: "-"
end
