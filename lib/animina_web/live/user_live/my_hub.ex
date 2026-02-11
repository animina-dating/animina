defmodule AniminaWeb.UserLive.MyHub do
  @moduledoc """
  Personal hub LiveView showing cards for all user-facing sections.
  """

  use AniminaWeb, :live_view

  alias Animina.Accounts.ProfileCompleteness

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <.header>
            {gettext("My Hub")}
            <:subtitle>{gettext("Your personal hub")}</:subtitle>
          </.header>
        </div>

        <div class="grid gap-3">
          <.hub_card
            :if={@user.state != "waitlisted"}
            navigate={~p"/discover"}
            icon="hero-sparkles"
            title={gettext("Discover")}
            subtitle={gettext("Find new people")}
          />
          <.hub_card
            :if={@user.state != "waitlisted"}
            navigate={~p"/my/messages"}
            icon="hero-chat-bubble-left-right"
            title={gettext("Messages")}
            subtitle={gettext("Your conversations")}
          />
          <.hub_card
            :if={@user.state == "waitlisted"}
            navigate={~p"/my/waitlist"}
            icon="hero-clock"
            title={gettext("Waitlist")}
            subtitle={gettext("Your account is on the waitlist")}
          />
          <.hub_card
            navigate={~p"/my/settings"}
            icon="hero-cog-6-tooth"
            title={gettext("Settings")}
            subtitle={@profile_preview}
          />
          <.hub_card
            navigate={~p"/my/logs"}
            icon="hero-document-text"
            title={gettext("Logs")}
            subtitle={gettext("Your account activity logs")}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    profile_completeness = ProfileCompleteness.compute(user)

    profile_preview =
      if profile_completeness.completed_count < profile_completeness.total_count do
        gettext("%{completed}/%{total} complete",
          completed: profile_completeness.completed_count,
          total: profile_completeness.total_count
        )
      else
        gettext("Profile complete")
      end

    {:ok,
     assign(socket,
       page_title: gettext("My Hub"),
       user: user,
       profile_preview: profile_preview
     )}
  end
end
