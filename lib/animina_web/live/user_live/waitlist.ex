defmodule AniminaWeb.UserLive.Waitlist do
  use AniminaWeb, :live_view

  alias Animina.Accounts
  alias Animina.Accounts.ProfileCompleteness
  alias Animina.FeatureFlags
  alias Animina.GeoData
  alias Animina.Moodboard
  alias Animina.Photos
  alias Animina.Traits
  alias AniminaWeb.ColumnToggle
  alias AniminaWeb.Helpers.ColumnPreferences

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/my"}>{gettext("My ANIMINA")}</.link>
            </li>
            <li>{gettext("Waitlist")}</li>
          </ul>
        </div>
        <%!-- Status banner --%>
        <div class="max-w-2xl mx-auto text-center">
          <p class="text-base-content/70">
            {gettext("Your account is on the waitlist.")}
          </p>
          <p
            :if={@end_waitlist_at && DateTime.compare(@end_waitlist_at, DateTime.utc_now()) == :gt}
            id="waitlist-countdown"
            phx-hook="WaitlistCountdown"
            data-end-waitlist-at={DateTime.to_iso8601(@end_waitlist_at)}
            data-locale={@current_scope.user.language}
            data-expired-text={gettext("Your activation is being processed")}
            class="text-2xl sm:text-3xl font-semibold text-base-content mt-2"
          >
            {gettext("approximately 2 weeks")}
          </p>
          <p
            :if={@end_waitlist_at && DateTime.compare(@end_waitlist_at, DateTime.utc_now()) == :gt}
            id="waitlist-subtext"
            class="text-base-content/70 mt-1"
          >
            {gettext("until your account is activated")}
          </p>
          <p
            :if={@end_waitlist_at && DateTime.compare(@end_waitlist_at, DateTime.utc_now()) != :gt}
            class="text-2xl sm:text-3xl font-semibold text-base-content mt-2"
          >
            {gettext("Your activation is being processed")}
          </p>
          <p
            :if={is_nil(@end_waitlist_at)}
            class="text-2xl sm:text-3xl font-semibold text-base-content mt-2"
          >
            {gettext("approximately 2 weeks")}
          </p>
          <p :if={is_nil(@end_waitlist_at)} class="text-base-content/70 mt-1">
            {gettext("until your account is activated")}
          </p>
        </div>

        <%!-- Prepare your profile --%>
        <div>
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-lg font-medium text-base-content">
                {gettext("Prepare your profile")}
              </h2>
              <p class="text-sm text-base-content/60">
                {gettext(
                  "Use the waiting time to set up your profile so you can get started right away."
                )}
              </p>
            </div>
            <div class="hidden sm:block">
              <ColumnToggle.column_toggle columns={@columns} />
            </div>
          </div>

          <div class={[
            "grid gap-3 grid-cols-1",
            ColumnPreferences.sm_grid_class(@columns),
            ColumnPreferences.md_grid_class(@columns)
          ]}>
            <.waitlist_card
              navigate={~p"/my/settings/profile/photo"}
              icon_bg="bg-secondary/10"
              icon_color="text-secondary"
              complete={@profile_completeness.items.profile_photo}
              avatar_url={if @avatar_photo, do: Photos.signed_url(@avatar_photo, :thumbnail)}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M4 5a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V7a2 2 0 00-2-2h-1.586a1 1 0 01-.707-.293l-1.121-1.121A2 2 0 0011.172 3H8.828a2 2 0 00-1.414.586L6.293 4.707A1 1 0 015.586 5H4zm6 9a3 3 0 100-6 3 3 0 000 6z"
                    clip-rule="evenodd"
                  />
                </svg>
              </:icon>
              <:title>{gettext("Profile Photo")}</:title>
              <:description>{gettext("Upload your main profile photo.")}</:description>
            </.waitlist_card>

            <.waitlist_card
              navigate={~p"/my/settings/profile/traits"}
              icon_bg="bg-success/10"
              icon_color="text-success"
              complete={@profile_completeness.items.flags}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </:icon>
              <:title>{gettext("Set up your flags")}</:title>
              <:description>
                {gettext("Define what you're about and what you're looking for.")}
              </:description>
              <:completed_description>
                {ngettext("%{count} flag set", "%{count} flags set", @flag_count, count: @flag_count)}
              </:completed_description>
            </.waitlist_card>

            <.waitlist_card
              navigate={~p"/my/settings/profile/moodboard"}
              icon_bg="bg-primary/10"
              icon_color="text-primary"
              complete={@profile_completeness.items.moodboard}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z"
                    clip-rule="evenodd"
                  />
                </svg>
              </:icon>
              <:title>{gettext("Edit Moodboard")}</:title>
              <:description>
                {gettext("Add photos and stories to make a great first impression.")}
              </:description>
              <:completed_description>
                {ngettext("%{count} item", "%{count} items", @moodboard_count,
                  count: @moodboard_count
                )}
              </:completed_description>
            </.waitlist_card>

            <.waitlist_card
              navigate={~p"/my/settings/account"}
              icon_bg="bg-info/10"
              icon_color="text-info"
              complete={@has_passkeys}
              optional={true}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M18 8a6 6 0 01-7.743 5.743L10 14l-1 1-1 1H6v2H2v-4l4.257-4.257A6 6 0 1118 8zm-6-4a1 1 0 100 2 2 2 0 012 2 1 1 0 102 0 4 4 0 00-4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
              </:icon>
              <:title>{gettext("Set up a passkey")}</:title>
              <:description>
                {gettext("Sign in faster and more securely with a passkey.")}
              </:description>
            </.waitlist_card>

            <.waitlist_card
              navigate={~p"/my/settings/blocked-contacts"}
              icon_bg="bg-warning/10"
              icon_color="text-warning"
              complete={@has_blocked_contacts}
              optional={true}
            >
              <:icon>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="w-5 h-5"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M13.477 14.89A6 6 0 015.11 6.524l8.367 8.368zm1.414-1.414L6.524 5.11a6 6 0 018.367 8.367zM18 10a8 8 0 11-16 0 8 8 0 0116 0z"
                    clip-rule="evenodd"
                  />
                </svg>
              </:icon>
              <:title>{gettext("Block contacts")}</:title>
              <:description>
                {gettext("Prevent ex-partners or acquaintances from seeing your profile.")}
              </:description>
              <:completed_description>
                {ngettext(
                  "%{count} contact blocked",
                  "%{count} contacts blocked",
                  @blocked_contacts_count,
                  count: @blocked_contacts_count
                )}
              </:completed_description>
            </.waitlist_card>

            <%!-- Invite friends (referral card) --%>
            <div class="rounded-lg border border-base-300 p-4">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center shrink-0 text-accent">
                  <.icon name="hero-share" class="w-5 h-5" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-base-content">{gettext("Skip the waitlist")}</p>
                  <p class="text-xs text-base-content/60">
                    {gettext("Share the code")}
                    <strong
                      id="referral-code"
                      class="font-bold text-base-content select-all"
                    >
                      {@referral_code}
                    </strong>
                    — {gettext("each confirmed signup halves the waitlist time for both of you.")}
                    <button
                      type="button"
                      class="inline-flex items-center text-base-content/40 hover:text-base-content/60 align-middle ml-0.5"
                      phx-click={JS.dispatch("phx:copy", to: "#referral-code")}
                    >
                      <.icon name="hero-clipboard-document" class="w-3.5 h-3.5" />
                    </button>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :navigate, :string, required: true
  attr :icon_bg, :string, required: true
  attr :icon_color, :string, required: true
  attr :complete, :boolean, required: true
  attr :optional, :boolean, default: false
  attr :avatar_url, :string, default: nil

  slot :icon, required: true
  slot :title, required: true
  slot :description, required: true
  slot :completed_description

  defp waitlist_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="flex items-center gap-3 rounded-lg border border-base-300 p-4 hover:bg-base-200 transition-colors relative"
    >
      <%= if @avatar_url && @complete do %>
        <img
          id="waitlist-avatar"
          src={@avatar_url}
          class="w-10 h-10 rounded-full object-cover shrink-0"
        />
      <% else %>
        <div class={"w-10 h-10 rounded-full #{@icon_bg} flex items-center justify-center shrink-0 #{@icon_color}"}>
          {render_slot(@icon)}
        </div>
      <% end %>
      <div class="flex-1 min-w-0">
        <p class="font-medium text-base-content">{render_slot(@title)}</p>
        <p class="text-xs text-base-content/60">
          <%= if @complete && @completed_description != [] do %>
            {render_slot(@completed_description)}
          <% else %>
            {render_slot(@description)}
          <% end %>
        </p>
      </div>
      <span class="shrink-0">
        <%= if @complete do %>
          <.icon name="hero-check-circle-solid" class="size-5 text-success" />
        <% else %>
          <%= if @optional do %>
            <span class="text-xs text-base-content/40 font-medium">{gettext("Optional")}</span>
          <% else %>
            <span class="inline-block size-5 rounded-full border-2 border-base-content/20" />
          <% end %>
        <% end %>
      </span>
    </.link>
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

    referral_count = Accounts.count_confirmed_referrals(user)
    referral_threshold = FeatureFlags.referral_threshold()
    has_passkeys = Accounts.list_user_passkeys(user) != []
    blocked_contacts_count = Accounts.count_contact_blacklist_entries(user)
    profile_completeness = ProfileCompleteness.compute(user)

    avatar_photo = Photos.get_user_avatar(user.id)
    flag_count = Traits.count_user_flags(user)
    moodboard_count = Moodboard.count_items(user.id)

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

    {:ok,
     socket
     |> assign(:page_title, page_title)
     |> assign(
       :page_description,
       gettext("Your account is on the waitlist. Prepare your profile while you wait.")
     )
     |> assign(:city_names, city_names)
     |> assign(:referral_code, user.referral_code)
     |> assign(:referral_count, referral_count)
     |> assign(:referral_threshold, referral_threshold)
     |> assign(:end_waitlist_at, user.end_waitlist_at)
     |> assign(:has_passkeys, has_passkeys)
     |> assign(:has_blocked_contacts, blocked_contacts_count > 0)
     |> assign(:blocked_contacts_count, blocked_contacts_count)
     |> assign(:avatar_photo, avatar_photo)
     |> assign(:flag_count, flag_count)
     |> assign(:moodboard_count, moodboard_count)
     |> assign(:columns, ColumnPreferences.get_columns_for_user(user))
     |> assign(:profile_completeness, profile_completeness)}
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
