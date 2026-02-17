defmodule AniminaWeb.UserLive.MyHub do
  @moduledoc """
  Personal hub LiveView showing cards for all user-facing sections.
  """

  use AniminaWeb, :live_view

  import AniminaWeb.WaitlistComponents

  alias AniminaWeb.Helpers.ColumnPreferences
  alias AniminaWeb.Helpers.WaitlistData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="max-w-2xl mx-auto">
          <h1 class="text-2xl font-semibold text-base-content">
            {gettext("Hey %{name}!", name: @user.display_name)}
          </h1>

          <%= if @profile_completeness.completed_count < @profile_completeness.total_count do %>
            <div class="mt-3">
              <div class="flex items-center justify-between text-sm text-base-content/60 mb-1">
                <span>
                  {gettext("Profile progress")}
                </span>
                <span>
                  {@profile_completeness.completed_count}/{@profile_completeness.total_count}
                </span>
              </div>
              <progress
                class="progress progress-primary w-full"
                value={@profile_completeness.completed_count}
                max={@profile_completeness.total_count}
              >
              </progress>
            </div>
          <% end %>
        </div>

        <%= if @user.state == "waitlisted" do %>
          <.waitlist_status_banner
            end_waitlist_at={@end_waitlist_at}
            current_scope={@current_scope}
          />
        <% else %>
          <div class="grid gap-3 grid-cols-1 sm:grid-cols-2">
            <.hub_card
              navigate={~p"/my/messages"}
              icon="hero-chat-bubble-left-right"
              title={gettext("Messages")}
              subtitle={gettext("Your conversations")}
            />
            <.hub_card
              navigate={~p"/my/spotlight"}
              icon="hero-sparkles"
              title={gettext("Spotlight")}
              subtitle={gettext("Find new people")}
            />
          </div>
        <% end %>

        <.waitlist_preparation_section
          columns={@columns}
          profile_completeness={@profile_completeness}
          avatar_photo={@avatar_photo}
          flag_count={@flag_count}
          moodboard_count={@moodboard_count}
          has_passkeys={@has_passkeys}
          has_blocked_contacts={@has_blocked_contacts}
          blocked_contacts_count={@blocked_contacts_count}
          waitlisted={@user.state == "waitlisted"}
          referral_code={@referral_code}
          referral_count={@referral_count}
          referral_threshold={@referral_threshold}
        />

        <div class="grid gap-3 grid-cols-1 sm:grid-cols-2 mt-3">
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
    waitlist_assigns = WaitlistData.load_waitlist_assigns(user)
    profile_completeness = waitlist_assigns[:profile_completeness]

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
        user: user,
        profile_preview: profile_preview
      )

    page_title =
      if user.state == "waitlisted" do
        days_remaining = waitlist_days_remaining(user.end_waitlist_at)

        if days_remaining && days_remaining > 0 do
          ngettext(
            "Waitlisted — %{count} day left",
            "Waitlisted — %{count} days left",
            days_remaining,
            count: days_remaining
          )
        else
          gettext("Waitlisted")
        end
      else
        gettext("My Hub")
      end

    socket =
      socket
      |> assign(:page_title, page_title)
      |> assign(:columns, ColumnPreferences.get_columns_for_user(user))
      |> assign(waitlist_assigns)

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

  defp waitlist_days_remaining(nil), do: nil

  defp waitlist_days_remaining(end_at) do
    diff = DateTime.diff(end_at, DateTime.utc_now(), :second)
    if diff > 0, do: div(diff, 86_400), else: 0
  end
end
