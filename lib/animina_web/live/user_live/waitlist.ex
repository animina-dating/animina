defmodule AniminaWeb.UserLive.Waitlist do
  use AniminaWeb, :live_view

  import AniminaWeb.WaitlistComponents

  alias Animina.GeoData
  alias AniminaWeb.Helpers.ColumnPreferences
  alias AniminaWeb.Helpers.WaitlistData

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/my"}>{gettext("My Hub")}</.link>
            </li>
            <li>{gettext("Waitlist")}</li>
          </ul>
        </div>

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
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    user = Animina.Repo.preload(user, :locations)

    city_names =
      user.locations
      |> Enum.sort_by(& &1.position)
      |> Enum.map_join(", ", fn loc ->
        case GeoData.get_city_by_zip_code(loc.zip_code) do
          %{name: name} -> name
          nil -> loc.zip_code
        end
      end)

    days_remaining = waitlist_days_remaining(user.end_waitlist_at)

    page_title =
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

    waitlist_assigns = WaitlistData.load_waitlist_assigns(user)

    {:ok,
     socket
     |> assign(:page_title, page_title)
     |> assign(
       :page_description,
       gettext("Your account is on the waitlist. Prepare your profile while you wait.")
     )
     |> assign(:city_names, city_names)
     |> assign(:columns, ColumnPreferences.get_columns_for_user(user))
     |> assign(waitlist_assigns)}
  end

  defp waitlist_days_remaining(nil), do: nil

  defp waitlist_days_remaining(end_at) do
    diff = DateTime.diff(end_at, DateTime.utc_now(), :second)
    if diff > 0, do: div(diff, 86_400), else: 0
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
