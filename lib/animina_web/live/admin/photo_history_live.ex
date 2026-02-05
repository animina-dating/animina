defmodule AniminaWeb.Admin.PhotoHistoryLive do
  use AniminaWeb, :live_view

  alias Animina.Photos

  import AniminaWeb.Helpers.AdminHelpers,
    only: [humanize_key: 1, format_value: 1, format_datetime_full: 1]

  @impl true
  def mount(%{"id" => photo_id}, _session, socket) do
    photo = Photos.get_photo!(photo_id)
    history = Photos.get_photo_history(photo_id)

    {:ok,
     assign(socket,
       page_title: gettext("Photo History"),
       photo: photo,
       history: history
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/admin/photo-reviews"}>{gettext("Photo Reviews")}</.link>
            </li>
            <li>{gettext("History")}</li>
          </ul>
        </div>

        <div class="flex items-start gap-6 mb-8">
          <%!-- Photo Preview --%>
          <div class="shrink-0">
            <img
              src={Photos.signed_url(@photo)}
              alt={gettext("Photo")}
              class="w-32 h-32 rounded-lg object-cover"
            />
          </div>

          <%!-- Photo Details --%>
          <div>
            <h1 class="text-2xl font-bold text-base-content mb-2">{gettext("Photo History")}</h1>
            <div class="flex flex-wrap gap-2">
              <span class={[
                "badge",
                state_badge_class(@photo.state)
              ]}>
                {@photo.state}
              </span>
              <%= if @photo.nsfw do %>
                <span class="badge badge-warning">{gettext("NSFW")}</span>
              <% end %>
              <%= if @photo.has_face == false do %>
                <span class="badge badge-error">{gettext("No Face")}</span>
              <% end %>
            </div>
            <p class="text-sm text-base-content/50 mt-2">
              {gettext("Photo ID: %{id}", id: @photo.id)}
            </p>
          </div>
        </div>

        <%!-- Timeline --%>
        <div class="relative">
          <%!-- Timeline Line --%>
          <div class="absolute left-4 top-0 bottom-0 w-0.5 bg-base-300"></div>

          <div class="space-y-4">
            <%= for event <- @history do %>
              <div class="relative flex gap-4">
                <%!-- Timeline Dot --%>
                <div class={[
                  "relative z-10 w-8 h-8 rounded-full flex items-center justify-center shrink-0",
                  actor_color(event.actor_type)
                ]}>
                  <.icon name={actor_icon(event.actor_type)} class="h-4 w-4" />
                </div>

                <%!-- Event Card --%>
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
                          <%= if event.actor do %>
                            <span class="ml-1">
                              - {event.actor.display_name}
                            </span>
                          <% end %>
                        </p>
                      </div>
                    </div>

                    <%!-- Duration and Server --%>
                    <%= if event.duration_ms || event.ollama_server_url do %>
                      <div class="mt-2 flex flex-wrap gap-2">
                        <%= if event.duration_ms do %>
                          <span class="badge badge-sm badge-ghost">
                            <.icon name="hero-clock" class="h-3 w-3 mr-1" />
                            {format_duration(event.duration_ms)}
                          </span>
                        <% end %>
                        <%= if event.ollama_server_url do %>
                          <span class="badge badge-sm badge-ghost">
                            <.icon name="hero-server" class="h-3 w-3 mr-1" />
                            {format_server_url(event.ollama_server_url)}
                          </span>
                        <% end %>
                      </div>
                    <% end %>

                    <%!-- Event Details --%>
                    <%= if event.details && map_size(event.details) > 0 do %>
                      <div class="mt-2 text-sm text-base-content/70">
                        <%= for {key, value} <- event.details do %>
                          <div class="flex gap-2">
                            <span class="font-medium text-base-content/50">{humanize_key(key)}:</span>
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

        <%= if @history == [] do %>
          <div class="text-center py-12">
            <.icon name="hero-document-text" class="h-16 w-16 mx-auto text-base-content/30 mb-4" />
            <p class="text-lg text-base-content/70">
              {gettext("No history recorded for this photo.")}
            </p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

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
