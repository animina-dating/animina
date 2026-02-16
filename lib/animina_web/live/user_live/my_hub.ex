defmodule AniminaWeb.UserLive.MyHub do
  @moduledoc """
  Personal hub LiveView showing cards for all user-facing sections.
  """

  use AniminaWeb, :live_view

  import AniminaWeb.WaitlistComponents

  alias Animina.Accounts.ProfileCompleteness
  alias AniminaWeb.Helpers.ColumnPreferences
  alias AniminaWeb.Helpers.WaitlistData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="max-w-2xl mx-auto">
          <div class="text-center mb-8">
            <.header>
              {gettext("My Hub")}
              <:subtitle>{gettext("Your personal hub")}</:subtitle>
            </.header>
          </div>
        </div>

        <%= if @user.state == "waitlisted" do %>
          <.waitlist_status_banner
            end_waitlist_at={@end_waitlist_at}
            current_scope={@current_scope}
          />

          <.waitlist_preparation_section
            columns={@columns}
            profile_completeness={@profile_completeness}
            avatar_photo={@avatar_photo}
            flag_count={@flag_count}
            moodboard_count={@moodboard_count}
            has_passkeys={@has_passkeys}
            has_blocked_contacts={@has_blocked_contacts}
            blocked_contacts_count={@blocked_contacts_count}
            referral_code={@referral_code}
            referral_count={@referral_count}
            referral_threshold={@referral_threshold}
          />
        <% end %>

        <div class="max-w-2xl mx-auto">
          <div class="grid gap-3">
            <.hub_card
              :if={@user.state != "waitlisted"}
              navigate={~p"/my/messages"}
              icon="hero-chat-bubble-left-right"
              title={gettext("Messages")}
              subtitle={gettext("Your conversations")}
            />
            <.hub_card
              :if={@user.state != "waitlisted"}
              navigate={~p"/my/spotlight"}
              icon="hero-sparkles"
              title={gettext("Spotlight")}
              subtitle={gettext("Find new people")}
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

    socket =
      assign(socket,
        page_title: gettext("My Hub"),
        user: user,
        profile_preview: profile_preview,
        profile_completeness: profile_completeness
      )

    socket =
      if user.state == "waitlisted" do
        waitlist_assigns = WaitlistData.load_waitlist_assigns(user)

        socket
        |> assign(:columns, ColumnPreferences.get_columns_for_user(user))
        |> assign(waitlist_assigns)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("change_columns", %{"columns" => columns_str}, socket) do
    {columns, updated_user} =
      ColumnPreferences.persist_columns(
        socket.assigns.current_scope.user,
        columns_str
      )

    {:noreply,
     socket
     |> assign(:columns, columns)
     |> ColumnPreferences.update_scope_user(updated_user)}
  end
end
