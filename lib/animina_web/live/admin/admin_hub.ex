defmodule AniminaWeb.Admin.AdminHub do
  @moduledoc """
  Admin hub LiveView showing cards for all admin sections.
  """

  use AniminaWeb, :live_view

  alias Animina.Photos
  alias AniminaWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    pending_reviews =
      Photos.count_pending_appeals(viewer_id: socket.assigns.current_scope.user.id)

    ollama_queue = Photos.count_ollama_queue()

    {:ok,
     assign(socket,
       page_title: gettext("Admin"),
       pending_reviews: pending_reviews,
       ollama_queue: ollama_queue
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <.header>
            {gettext("Administration")}
            <:subtitle>{gettext("Manage your ANIMINA instance")}</:subtitle>
          </.header>
        </div>

        <div class="grid gap-3">
          <.hub_card
            navigate={~p"/admin/photo-reviews"}
            icon="hero-photo"
            title={gettext("Photo Reviews")}
            subtitle={gettext("Review reported and flagged photos")}
          >
            <:trailing>
              <span :if={@pending_reviews > 0} class="badge badge-error">
                {@pending_reviews}
              </span>
            </:trailing>
          </.hub_card>
          <.hub_card
            navigate={~p"/admin/photo-blacklist"}
            icon="hero-no-symbol"
            title={gettext("Photo Blacklist")}
            subtitle={gettext("Manage blacklisted photo hashes")}
          />
          <.hub_card
            navigate={~p"/admin/roles"}
            icon="hero-user-group"
            title={gettext("Manage Roles")}
            subtitle={gettext("Assign admin and moderator roles")}
          />
          <.hub_card
            navigate={~p"/admin/flags"}
            icon="hero-flag"
            title={gettext("Feature Flags")}
            subtitle={gettext("Toggle features and system settings")}
          />
          <.hub_card
            navigate={~p"/admin/logs"}
            icon="hero-clipboard-document-list"
            title={gettext("Logs")}
            subtitle={gettext("System log viewers")}
          >
            <:trailing>
              <span :if={@ollama_queue > 0} class="badge badge-warning">
                {@ollama_queue}
              </span>
            </:trailing>
          </.hub_card>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
